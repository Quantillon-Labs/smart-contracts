// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IQuantillonVault} from "../interfaces/IQuantillonVault.sol";
import {IOracle} from "../interfaces/IOracle.sol";

interface IRebalancerSafe {
    function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        returns (bool success, bytes memory returnData);
}

/**
 * @title QuantillonRebalancerModule
 * @notice A Safe-owned, non-upgradeable permission to add/remove margin on one position.
 * @dev No arbitrary execution, transfers, delegatecalls, position entry/exit or bridging.
 *      The operator pays gas; USDC always moves between the Safe and HedgerPool's vault.
 *      Install only after independent review. Policy changes require a call from the Safe.
 * @custom:security-contact team@quantillon.money
 */
contract QuantillonRebalancerModule is ReentrancyGuard {
    struct Limits {
        uint256 maxActionUsdc;
        uint256 maxWindowUsdc;
        uint256 cooldownSeconds;
        uint256 minSafeReserveUsdc;
        uint256 minMarginBps;
        uint256 marginBufferBps;
        uint256 vaultCrBufferBps;
    }

    address public immutable safe;
    IHedgerPool public immutable hedgerPool;
    IERC20 public immutable usdc;
    IQuantillonVault public immutable vault;
    uint256 public immutable positionId;
    address public operator;
    bool public paused = true;
    Limits public limits;
    uint256 public nonce;
    uint256 public lastExecution;
    uint256 public usageDay;
    uint256 public currentDayUsage;
    uint256 public previousDayUsage;

    error Unauthorized();
    error InvalidConfiguration();
    error ModulePaused();
    error InvalidRequest();
    error WrongPositionOwner();
    error DependenciesChanged();
    error LimitExceeded();
    error CooldownActive();
    error InvalidOracle();
    error PositionFloorBreached();
    error VaultFloorBreached();
    error SafeReserveBreached();
    error SafeExecutionFailed();
    error TokenOperationFailed();
    error UnexpectedBalanceChange();

    event Configured(address indexed operator, Limits limits);
    event PauseChanged(bool paused);
    event MarginRebalanced(uint256 indexed nonce, uint256 indexed positionId, bool increase, uint256 amount);

    constructor(address safe_, address pool_, uint256 positionId_, address operator_, Limits memory limits_) {
        if (safe_.code.length == 0 || pool_.code.length == 0 || positionId_ != 1) revert InvalidConfiguration();
        safe = safe_;
        hedgerPool = IHedgerPool(pool_);
        usdc = IHedgerPool(pool_).usdc();
        vault = IQuantillonVault(IHedgerPool(pool_).vault());
        if (address(vault).code.length == 0 || IERC20Metadata(address(usdc)).decimals() != 6) {
            revert InvalidConfiguration();
        }
        positionId = positionId_;
        _configure(operator_, limits_);
    }

    /// @notice Reports this standalone module's release version.
    function version() external pure returns (string memory) {
        return "1.0.1";
    }

    /// @notice Changes the operator and policy; existing usage and cooldown are preserved.
    function configure(address operator_, Limits calldata limits_) external nonReentrant {
        if (msg.sender != safe) revert Unauthorized();
        _configure(operator_, limits_);
    }

    /// @notice Lets the Safe pause or resume automation without blocking its owner transactions.
    function setPaused(bool paused_) external nonReentrant {
        if (msg.sender != safe) revert Unauthorized();
        paused = paused_;
        emit PauseChanged(paused_);
    }

    /// @notice Adds margin using an exact, atomic Safe approval and preserves its reserve.
    /// @dev Deposits remain possible with an invalid oracle to allow collateral recovery.
    function addMargin(uint256 amount, uint256 expectedNonce, uint256 deadline) external nonReentrant {
        _authorize(amount, expectedNonce, deadline);
        uint256 beforeBalance = usdc.balanceOf(safe);
        if (amount > beforeBalance || beforeBalance - amount < limits.minSafeReserveUsdc) revert SafeReserveBreached();
        _approve(0);
        _approve(amount);
        _execute(address(hedgerPool), abi.encodeCall(IHedgerPool.addMargin, (positionId, amount)));
        _approve(0);
        if (usdc.balanceOf(safe) != beforeBalance - amount) revert UnexpectedBalanceChange();
        emit MarginRebalanced(expectedNonce, positionId, true, amount);
    }

    /// @notice Removes margin to the Safe, then checks fresh position and protocol solvency atomically.
    function removeMargin(uint256 amount, uint256 expectedNonce, uint256 deadline) external nonReentrant {
        _authorize(amount, expectedNonce, deadline);
        uint256 beforeBalance = usdc.balanceOf(safe);
        _execute(address(hedgerPool), abi.encodeCall(IHedgerPool.removeMargin, (positionId, amount)));
        _checkWithdrawalFloors();
        if (usdc.balanceOf(safe) != beforeBalance + amount) revert UnexpectedBalanceChange();
        emit MarginRebalanced(expectedNonce, positionId, false, amount);
    }

    /// @notice Conservative rolling-day usage: sum of the current and previous UTC day.
    /// @dev This bounds every rolling 24h period, but can retain usage for almost 48h.
    function windowUsage() public view returns (uint256) {
        uint256 day = block.timestamp / 1 days;
        if (day == usageDay) return currentDayUsage + previousDayUsage;
        if (day == usageDay + 1) return currentDayUsage;
        return 0;
    }

    function _configure(address operator_, Limits memory limits_) private {
        if (
            operator_ == address(0) || operator_ == safe || limits_.maxActionUsdc == 0
                || limits_.maxWindowUsdc < limits_.maxActionUsdc || limits_.cooldownSeconds < 60
                || limits_.minMarginBps < 250 || limits_.minMarginBps > 10_000 || limits_.marginBufferBps > 10_000
                || limits_.vaultCrBufferBps > 10_000
        ) {
            revert InvalidConfiguration();
        }
        operator = operator_;
        limits = limits_;
        emit Configured(operator_, limits_);
    }

    function _authorize(uint256 amount, uint256 expectedNonce, uint256 deadline) private {
        if (msg.sender != operator) revert Unauthorized();
        if (paused) revert ModulePaused();
        if (
            expectedNonce != nonce || deadline < block.timestamp || deadline > block.timestamp + 15 minutes
                || amount == 0
        ) {
            revert InvalidRequest();
        }
        if (
            address(hedgerPool.usdc()) != address(usdc) || hedgerPool.vault() != address(vault)
                || !hedgerPool.costBasisAccountingInitialized()
        ) revert DependenciesChanged();
        (address owner,,,,,,,,,, bool active,,) = hedgerPool.positions(positionId);
        if (!active || owner != safe || hedgerPool.singleHedger() != safe) revert WrongPositionOwner();
        if (amount > limits.maxActionUsdc || windowUsage() + amount > limits.maxWindowUsdc) revert LimitExceeded();
        if (nonce != 0 && block.timestamp < lastExecution + limits.cooldownSeconds) revert CooldownActive();
        uint256 day = block.timestamp / 1 days;
        if (day != usageDay) {
            previousDayUsage = day == usageDay + 1 ? currentDayUsage : 0;
            currentDayUsage = 0;
            usageDay = day;
        }
        currentDayUsage += amount;
        lastExecution = block.timestamp;
        ++nonce;
    }

    function _checkWithdrawalFloors() private {
        (uint256 price, bool valid) = IOracle(hedgerPool.oracle()).getEurUsdPrice();
        if (!valid || price == 0) revert InvalidOracle();
        (,,,,,,,,,,, uint128 backing,) = hedgerPool.positions(positionId);
        (uint64 contractFloor,,,,,,,) = hedgerPool.coreParams();
        uint256 floor = Math.max(limits.minMarginBps, uint256(contractFloor) + limits.marginBufferBps);
        uint256 liability = Math.mulDiv(uint256(backing), price, 1e30, Math.Rounding.Ceil);
        uint256 required = Math.mulDiv(liability, floor, 10_000, Math.Rounding.Ceil);
        // Remaining-cost accounting already includes realized PnL in cash margin.
        if (hedgerPool.getTotalEffectiveHedgerCollateral(price) < required) revert PositionFloorBreached();

        uint256 supply = IERC20(vault.qeuro()).totalSupply();
        if (supply == 0) return;
        uint256 debt = Math.mulDiv(supply, price, 1e30, Math.Rounding.Ceil);
        uint256 minimum = vault.minCollateralizationRatioForMinting() + limits.vaultCrBufferBps * 1e16;
        // Evaluate at the fresh oracle price, not the vault's advisory cached-price CR.
        if (vault.getTotalUsdcAvailable() < Math.mulDiv(debt, minimum, 1e20, Math.Rounding.Ceil)) {
            revert VaultFloorBreached();
        }
    }

    function _approve(uint256 amount) private {
        bytes memory result = _execute(address(usdc), abi.encodeCall(IERC20.approve, (address(hedgerPool), amount)));
        if (result.length != 0 && (result.length != 32 || !abi.decode(result, (bool)))) revert TokenOperationFailed();
    }

    function _execute(address target, bytes memory data) private returns (bytes memory result) {
        bool success;
        (success, result) = IRebalancerSafe(safe).execTransactionFromModuleReturnData(target, 0, data, 0);
        if (!success) revert SafeExecutionFailed();
    }
}
