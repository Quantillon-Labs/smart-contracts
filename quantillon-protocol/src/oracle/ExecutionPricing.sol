// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IExecutionPricing} from "../interfaces/IExecutionPricing.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {CommonErrorLibrary as Errors} from "../libraries/CommonErrorLibrary.sol";

/// @notice Vault reads required for execution previews.
interface IExecutionVault {
    /**
     * @notice Whether vault settlement is paused for governance changes.
     * @dev Read-only access to the vault's pause state.
     * @return True while settlement is paused.
     * @custom:security Used to gate pricing-limit changes.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates downstream read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle None.
     */
    function paused() external view returns (bool);
    /**
     * @notice Read the vault reference oracle address.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Value returned by the read interface.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function oracle() external view returns (address);
    /**
     * @notice Read the USDC token address.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Value returned by the read interface.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function usdc() external view returns (address);
    /**
     * @notice Read the protocol mint fee fraction.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Value returned by the read interface.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function mintFee() external view returns (uint256);
    /**
     * @notice Read the protocol redemption fee fraction.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Value returned by the read interface.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function redemptionFee() external view returns (uint256);
}

/// @notice Router reads binding depth to the active hedge venue.
interface IExecutionRouter {
    /**
     * @notice Read the active router slot.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Value returned by the read interface.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function activeOracle() external view returns (uint8);
    /**
     * @notice Read the router market oracle address.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Value returned by the read interface.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function marketOracle() external view returns (address);
}

/// @title ExecutionPricing
/// @notice Bounded, directional order-book pricing with persistent admission accounting.
/// @dev Non-upgradeable module. Governance configures it on a paused vault after publishing depth.
///      Reporter acknowledgments attest completed hedges; publishing alone never releases exposure.
contract ExecutionPricing is AccessControl, IExecutionPricing {
    using SafeERC20 for IERC20;
    uint256 private constant SCALE = 1e30; // EUR(18) * USD/EUR(18) -> USDC(6)
    uint256 private constant BPS = 10_000;
    /// @notice Maximum number of executable price levels on each side.
    uint256 public constant MAX_LEVELS = 20;
    /// @notice Role authorized to publish observed Hyperliquid depth.
    bytes32 public constant WRITER_ROLE = keccak256("WRITER_ROLE");
    /// @notice Role authorized to acknowledge hedged exposure and margin capacity.
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");
    /// @notice Vault authorized to consume liquidity.
    address public immutable override vault;
    /// @notice Hyperliquid oracle required in the router's active market slot.
    address public immutable venueOracle;
    /// @notice Recipient of execution spread reserves.
    address public immutable reserveRecipient;
    /// @notice Maximum book and capacity observation age in seconds.
    uint256 public maxAge;
    /// @notice Maximum per-level deviation from the reference price in basis points.
    uint256 public maxImpactBps;
    /// @notice Venue fee and timing allowance incorporated into each execution rate.
    uint256 public bufferBps;
    /// @notice Governance ceiling on admitted unacknowledged EUR exposure.
    uint256 public maxOutstanding;
    /// @notice Governance-update timestamp; subsequent reports must be observed after this time.
    uint256 public riskLimitsUpdatedAt;

    /// @notice A price level with USD/EUR price and EUR quantity, both in 18 decimals.
    struct Level { uint128 price; uint128 quantity; }
    /// @notice Contract preview, including user output after protocol fees.
    struct Quote {
        uint256 amountOut;
        uint256 executionRate;
        uint256 referenceRate;
        uint256 capacityQeuro;
        uint256 observedAt;
        uint256 sequence;
    }
    Level[] private asks;
    Level[] private bids;
    /// @notice Original source observation time; never replaced by publication time.
    uint256 public observedAt;
    /// @notice Monotonic accepted snapshot revision.
    uint256 public sequence;
    /// @notice Buy-side quantity consumed from the current admission epoch.
    uint256 public usedBuy;
    /// @notice Sell-side quantity consumed from the current admission epoch.
    uint256 public usedSell;
    /// @notice Lifetime admitted quantities, used as replay-safe acknowledgment cursors.
    uint256 public admittedBuy;
    uint256 public admittedSell;
    /// @notice Lifetime hedge-acknowledged quantities.
    uint256 public acknowledgedBuy;
    uint256 public acknowledgedSell;
    /// @notice Time of the last complete hedge acknowledgment.
    uint256 public acknowledgedAt;
    /// @notice Last block in which exposure was consumed.
    uint256 public lastConsumptionBlock;
    /// @notice Reporter-certified additional margin capacity in EUR and its observation time.
    uint256 public marginCapacity;
    uint256 public capacityObservedAt;

    event BookPublished(uint256 indexed sequence, uint256 observedAt, uint256 usedBuy, uint256 usedSell);
    event LiquidityConsumed(bool indexed mint, uint256 quantity, uint256 referencePrice, uint256 executionUsdc, uint256 admittedBuy, uint256 admittedSell);
    event HedgeAcknowledged(uint256 admittedBuy, uint256 admittedSell, uint256 capacity, uint256 observedAt);
    event ReserveWithdrawn(address indexed recipient, uint256 amount);
    event RiskLimitsUpdated(uint256 maxAge, uint256 maxImpactBps, uint256 bufferBps, uint256 maxOutstanding);

    /**
     * @notice Deploy a vault-bound pricing module with explicit initial risk ceilings.
     * @param addresses Vault, Hyperliquid oracle, governance, depth writer, hedge reporter, reserve recipient.
     * @param limits Maximum age (seconds), maximum impact (bps), rate buffer (bps), max outstanding EUR (18 decimals).
     * @custom:security Explicit role separation; no default economic limits are inferred.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Deployment only; explicit role recipients are required.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    constructor(address[6] memory addresses, uint256[4] memory limits) {
        for (uint256 i; i < addresses.length; ++i) if (addresses[i] == address(0)) revert Errors.ZeroAddress();
        _validateRiskLimits(limits[0], limits[1], limits[2], limits[3]);
        vault = addresses[0]; venueOracle = addresses[1]; reserveRecipient = addresses[5];
        maxAge = limits[0]; maxImpactBps = limits[1]; bufferBps = limits[2]; maxOutstanding = limits[3];
        _grantRole(DEFAULT_ADMIN_ROLE, addresses[2]);
        _grantRole(WRITER_ROLE, addresses[3]);
        _grantRole(REPORTER_ROLE, addresses[4]);
    }

    /**
     * @notice Implementation semantic version.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function version() external pure returns (string memory) { return "1.1.0"; }

    /**
     * @notice Update pricing limits on a paused vault after all admitted hedges are acknowledged.
     * @dev Invalidates depth and capacity so subsequent quotes require newly observed reports.
     * @param age Maximum source age in seconds, from 1 to 300.
     * @param impact Maximum total per-level execution impact in bps, from 1 to 500.
     * @param buffer Execution-rate buffer in bps, no greater than impact.
     * @param outstandingLimit Aggregate unacknowledged EUR ceiling in 18 decimals.
     * @custom:security Governance only; cannot change the terms of pending admission.
     * @custom:validation Requires paused settlement, zero outstanding admission and bounded limits.
     * @custom:state-changes Updates limits, invalidates reports and clears consumed depth.
     * @custom:events RiskLimitsUpdated.
     * @custom:errors InvalidCondition for unsettled/unpaused vault; InvalidParameter for invalid limits.
     * @custom:reentrancy Only a read-only call to the immutable vault.
     * @custom:access DEFAULT_ADMIN_ROLE.
     * @custom:oracle Fresh reports observed after the change are required before quoting.
     */
    function updateRiskLimits(uint256 age, uint256 impact, uint256 buffer, uint256 outstandingLimit)
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (!IExecutionVault(vault).paused() || outstanding() != 0) revert Errors.InvalidCondition();
        _validateRiskLimits(age, impact, buffer, outstandingLimit);
        maxAge = age;
        maxImpactBps = impact;
        bufferBps = buffer;
        maxOutstanding = outstandingLimit;
        riskLimitsUpdatedAt = block.timestamp;
        observedAt = 0;
        capacityObservedAt = 0;
        marginCapacity = 0;
        usedBuy = 0;
        usedSell = 0;
        delete asks;
        delete bids;
        emit RiskLimitsUpdated(age, impact, buffer, outstandingLimit);
    }

    /// @notice Validate pricing risk limits.
    /// @dev Applies the same bounds during deployment and governance updates.
    /// @param age Maximum source age in seconds.
    /// @param impact Maximum total execution impact in bps.
    /// @param buffer Execution-rate buffer in bps.
    /// @param outstandingLimit Unacknowledged EUR limit in 18 decimals.
    /// @custom:security Caps source age and per-level impact.
    /// @custom:validation Age 1–300, impact 1–500, buffer at most impact, positive exposure limit.
    /// @custom:state-changes None.
    /// @custom:events None.
    /// @custom:errors InvalidParameter.
    /// @custom:reentrancy None.
    /// @custom:access Internal.
    /// @custom:oracle None.
    function _validateRiskLimits(uint256 age, uint256 impact, uint256 buffer, uint256 outstandingLimit) private pure {
        if (age == 0 || age > 300 || impact == 0 || impact > 500 || buffer > impact || outstandingLimit == 0) {
            revert Errors.InvalidParameter();
        }
    }

    /**
     * @notice Publish strictly ordered book levels with the original exchange timestamp.
     * @param sourceTime Source observation timestamp in seconds.
     * @param buy Asks ordered by ascending price.
     * @param sell Bids ordered by descending price.
     * @custom:security A newer observation cannot clear outstanding exposure or reset used depth prematurely.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access WRITER_ROLE only.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function publish(uint256 sourceTime, Level[] calldata buy, Level[] calldata sell) external onlyRole(WRITER_ROLE) {
        if (sourceTime <= observedAt || sourceTime <= riskLimitsUpdatedAt || sourceTime > block.timestamp || block.timestamp - sourceTime > maxAge) revert Errors.InvalidTime();
        _checkLevels(buy, true); _checkLevels(sell, false);
        if (sell[0].price > buy[0].price) revert Errors.InvalidPrice();
        if (outstanding() == 0 && sourceTime > acknowledgedAt) { usedBuy = 0; usedSell = 0; }
        delete asks; delete bids;
        for (uint256 i; i < buy.length; ++i) asks.push(buy[i]);
        for (uint256 i; i < sell.length; ++i) bids.push(sell[i]);
        observedAt = sourceTime;
        emit BookPublished(++sequence, sourceTime, usedBuy, usedSell);
    }

    /**
     * @notice Acknowledge all currently admitted exposure after canonical fills are reconciled.
     * @param buy Expected lifetime admitted buy quantity; rejects concurrent consumption.
     * @param sell Expected lifetime admitted sell quantity; rejects concurrent consumption.
     * @param capacity Additional EUR capacity supported by currently available venue margin.
     * @param sourceTime Original account observation time in seconds.
     * @custom:security Trusted reporter must reconcile fills and Base finality before calling; timestamps alone are not evidence.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access REPORTER_ROLE only.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function acknowledge(uint256 buy, uint256 sell, uint256 capacity, uint256 sourceTime) external onlyRole(REPORTER_ROLE) {
        if (buy != admittedBuy || sell != admittedSell) revert Errors.InvalidAmount();
        if (sourceTime <= riskLimitsUpdatedAt || sourceTime > block.timestamp || sourceTime < capacityObservedAt || block.timestamp - sourceTime > maxAge) revert Errors.InvalidTime();
        if (buy != acknowledgedBuy || sell != acknowledgedSell) acknowledgedAt = block.timestamp;
        acknowledgedBuy = buy; acknowledgedSell = sell;
        marginCapacity = Math.min(capacity, maxOutstanding); capacityObservedAt = sourceTime;
        emit HedgeAcknowledged(buy, sell, marginCapacity, sourceTime);
    }

    /**
     * @notice Unacknowledged exposure across both directions, without speculative netting.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function outstanding() public view override returns (uint256) {
        return admittedBuy - acknowledgedBuy + admittedSell - acknowledgedSell;
    }

    /**
     * @notice Remaining executable EUR capacity on each side, including outstanding exposure limits.
     * @return buy Buy capacity in 18-decimal EUR units.
     * @return sell Sell capacity in 18-decimal EUR units.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function availableCapacity() external view returns (uint256 buy, uint256 sell) {
        uint256 ref = _reference();
        _validate(ref);
        return (_capacity(true, ref), _capacity(false, ref));
    }

    /**
     * @notice Exact-USDC-input mint preview, after the vault's protocol fee.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param usdcInput Value supplied to this operation.
     * @return quote Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function previewMint(uint256 usdcInput) external view returns (Quote memory quote) {
        uint256 ref = _reference();
        uint256 net = usdcInput - Math.mulDiv(usdcInput, IExecutionVault(vault).mintFee(), 1e18);
        (uint256 q,) = _mint(net, ref);
        quote = Quote(q, Math.mulDiv(net, SCALE, q), ref, _capacity(true, ref), observedAt, sequence);
    }

    /**
     * @notice Exact-QEURO-input normal-redemption preview, after the reference-valued protocol fee.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param qeuroInput Value supplied to this operation.
     * @return quote Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function previewRedeem(uint256 qeuroInput) external view returns (Quote memory quote) {
        uint256 ref = _reference();
        uint256 payout = _redeem(qeuroInput, ref);
        uint256 fee = Math.mulDiv(Math.mulDiv(qeuroInput, ref, SCALE), IExecutionVault(vault).redemptionFee(), 1e18);
        if (payout <= fee) revert Errors.InvalidAmount();
        quote = Quote(payout - fee, Math.mulDiv(payout, SCALE, qeuroInput), ref, _capacity(false, ref), observedAt, sequence);
    }

    /**
     * @notice Consume buy liquidity and return minted quantity and reference backing.
     * @inheritdoc IExecutionPricing
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param netUsdc Net USDC input in 6 decimals.
     * @param ref Reference USD per EUR price in 18 decimals.
     * @return q Calculated result in the units described by this operation.
     * @return backing Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Updates consumed liquidity counters.
     * @custom:events LiquidityConsumed.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function consumeMint(uint256 netUsdc, uint256 ref) external override returns (uint256 q, uint256 backing) {
        if (msg.sender != vault) revert Errors.NotAuthorized();
        (q, backing) = _mint(netUsdc, ref);
        usedBuy += q; admittedBuy += q; lastConsumptionBlock = block.number;
        emit LiquidityConsumed(true, q, ref, netUsdc, admittedBuy, admittedSell);
    }

    /**
     * @notice Consume sell liquidity and return the execution-valued payout.
     * @inheritdoc IExecutionPricing
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param q QEURO quantity in 18 decimals.
     * @param ref Reference USD per EUR price in 18 decimals.
     * @return payout Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Updates consumed liquidity counters.
     * @custom:events LiquidityConsumed.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function consumeRedeem(uint256 q, uint256 ref) external override returns (uint256 payout) {
        if (msg.sender != vault) revert Errors.NotAuthorized();
        payout = _redeem(q, ref);
        usedSell += q; admittedSell += q; lastConsumptionBlock = block.number;
        emit LiquidityConsumed(false, q, ref, payout, admittedBuy, admittedSell);
    }

    /**
     * @notice Transfer collected execution spreads to the immutable hedge reserve recipient.
     * @param amount USDC amount in 6 decimals.
     * @custom:security Governance cannot redirect the reserve to an arbitrary recipient.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access DEFAULT_ADMIN_ROLE only.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function withdrawReserve(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(IExecutionVault(vault).usdc()).safeTransfer(reserveRecipient, amount);
        emit ReserveWithdrawn(reserveRecipient, amount);
    }

    /**
     * @notice Validate nonzero strictly ordered executable book levels.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param levels Ordered executable price and quantity levels.
     * @param buy True for the buy side, false for the sell side.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Private helper.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function _checkLevels(Level[] calldata levels, bool buy) private pure {
        if (levels.length == 0 || levels.length > MAX_LEVELS) revert Errors.InvalidAmount();
        for (uint256 i; i < levels.length; ++i) {
            if (levels[i].price == 0 || levels[i].quantity == 0) revert Errors.InvalidAmount();
            if (i > 0 && (buy ? levels[i].price <= levels[i-1].price : levels[i].price >= levels[i-1].price)) revert Errors.InvalidPrice();
        }
    }

    /**
     * @notice Read a valid reference price for execution previews.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return ref Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Private helper.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function _reference() private view returns (uint256 ref) {
        (uint256 price,,, bool stale, bool bounds) = IOracle(IExecutionVault(vault).oracle()).getEurUsdDetails();
        if (stale || !bounds || price == 0) revert Errors.InvalidOraclePrice();
        return price;
    }

    /**
     * @notice Validate reference coherence, venue and observation freshness.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param ref Reference USD per EUR price in 18 decimals.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Private helper.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function _validate(uint256 ref) private view {
        if (ref == 0 || observedAt == 0 || block.timestamp - observedAt > maxAge || capacityObservedAt == 0 || block.timestamp - capacityObservedAt > maxAge) revert Errors.InvalidOraclePrice();
        IExecutionRouter router = IExecutionRouter(IExecutionVault(vault).oracle());
        if (router.activeOracle() != 1 || router.marketOracle() != venueOracle) revert Errors.InvalidOracle();
        uint256 mid = (uint256(asks[0].price) + bids[0].price) / 2;
        if (Math.mulDiv(mid > ref ? mid-ref : ref-mid, BPS, ref, Math.Rounding.Ceil) > maxImpactBps) revert Errors.InvalidPrice();
    }

    /**
     * @notice Calculate a conservative per-level execution rate.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param price USD per EUR price in 18 decimals.
     * @param buy True for the buy side, false for the sell side.
     * @param ref Reference USD per EUR price in 18 decimals.
     * @return result Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Private helper.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function _rate(uint256 price, bool buy, uint256 ref) private view returns (uint256) {
        return buy
            ? Math.mulDiv(Math.max(price, ref), BPS + bufferBps, BPS, Math.Rounding.Ceil)
            : Math.mulDiv(Math.min(price, ref), BPS - bufferBps, BPS);
    }

    /**
     * @notice Calculate remaining admitted capacity at the configured price limit.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param buy True for the buy side, false for the sell side.
     * @param ref Reference USD per EUR price in 18 decimals.
     * @return capacity Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Private helper.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function _capacity(bool buy, uint256 ref) private view returns (uint256 capacity) {
        Level[] storage levels = buy ? asks : bids;
        uint256 skip = buy ? usedBuy : usedSell;
        for (uint256 i; i < levels.length; ++i) {
            uint256 rate = _rate(levels[i].price, buy, ref);
            if (buy ? rate > Math.mulDiv(ref, BPS + maxImpactBps, BPS) : rate < Math.mulDiv(ref, BPS - maxImpactBps, BPS, Math.Rounding.Ceil)) break;
            uint256 quantity = levels[i].quantity;
            if (skip >= quantity) { skip -= quantity; continue; }
            capacity += quantity - skip; skip = 0;
        }
        uint256 limit = Math.min(maxOutstanding, marginCapacity);
        uint256 pending = outstanding();
        return Math.min(capacity, pending >= limit ? 0 : limit - pending);
    }

    /**
     * @notice Invert cumulative buy cost for an exact USDC input.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param budget Net USDC input in 6 decimals.
     * @param ref Reference USD per EUR price in 18 decimals.
     * @return q Calculated result in the units described by this operation.
     * @return backing Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Private helper.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function _mint(uint256 budget, uint256 ref) private view returns (uint256 q, uint256 backing) {
        _validate(ref);
        if (budget == 0) revert Errors.InvalidAmount();
        uint256 skip = usedBuy;
        uint256 remaining = budget;
        for (uint256 i; i < asks.length && remaining > 0; ++i) {
            uint256 size = asks[i].quantity;
            if (skip >= size) { skip -= size; continue; }
            size -= skip; skip = 0;
            uint256 rate = _rate(asks[i].price, true, ref);
            uint256 fill = Math.min(size, Math.mulDiv(remaining, SCALE, rate));
            q += fill;
            remaining -= Math.mulDiv(fill, rate, SCALE, Math.Rounding.Ceil);
        }
        if (remaining != 0 || q == 0 || q > _capacity(true, ref)) revert Errors.InsufficientBalance();
        backing = Math.mulDiv(q, ref, SCALE);
        if (backing == 0) revert Errors.InvalidAmount();
    }

    /**
     * @notice Calculate cumulative sell proceeds for a QEURO input.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @param q QEURO quantity in 18 decimals.
     * @param ref Reference USD per EUR price in 18 decimals.
     * @return payout Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Private helper.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function _redeem(uint256 q, uint256 ref) private view returns (uint256 payout) {
        _validate(ref);
        if (q == 0 || q > _capacity(false, ref)) revert Errors.InsufficientBalance();
        uint256 skip = usedSell;
        uint256 remaining = q;
        for (uint256 i; i < bids.length && remaining > 0; ++i) {
            uint256 size = bids[i].quantity;
            if (skip >= size) { skip -= size; continue; }
            size -= skip; skip = 0;
            uint256 fill = Math.min(size, remaining);
            payout += Math.mulDiv(fill, _rate(bids[i].price, false, ref), SCALE);
            remaining -= fill;
        }
        if (remaining != 0 || payout == 0) revert Errors.InsufficientBalance();
    }
}
