// /test/DeploymentSmoke.t.sol
// Lightweight deployment & wiring smoke tests for the core protocol.
// This file exists to mirror the documented multi-phase deployment strategy.
// It helps catch deployment and wiring regressions early.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Core contracts
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {FeeCollector} from "../src/core/FeeCollector.sol";
import {YieldShift} from "../src/core/yieldmanagement/YieldShift.sol";
import {AaveVault} from "../src/core/vaults/AaveVault.sol";

// Oracle + mocks
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {MockAggregatorV3} from "./ChainlinkOracle.t.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/// @notice Deployment smoke tests that roughly mirror the 4‑phase deployment plan.
contract DeploymentSmokeTest is Test {
    // Core instances
    TimeProvider public timeProvider;
    QEUROToken public qeuroToken;
    QTIToken public qtiToken;
    QuantillonVault public vault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    stQEUROToken public stQEURO;
    FeeCollector public feeCollector;
    YieldShift public yieldShift;
    MockChainlinkOracle public oracle;
    MockUSDC public usdc;
    MockAggregatorV3 public eurUsdFeed;
    MockAggregatorV3 public usdcUsdFeed;

    // Addresses
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public governance = address(0x3);
    address public emergency = address(0x4);
    address public user1 = address(0x5);
    address public hedger1 = address(0x6);
    address public timelock = address(0x7);

    // Constants
    uint256 public constant INITIAL_USDC_AMOUNT = 1_000_000 * 1e6;
    uint256 public constant DEPOSIT_AMOUNT = 5_000 * 1e6;
    uint256 public constant EUR_USD_PRICE = 1.10e8; // 1.10 USD per EUR (8 decimals)
    uint256 public constant USDC_USD_PRICE = 1.00e8; // 1.00 USD per USDC (8 decimals)

    /// @notice Single entrypoint to deploy the full protocol in 4 logical phases.
    function deployFullProtocol() internal {
        _phaseA_timeProviderOracleQeuroFeeCollectorVault();
        _phaseB_qtiAaveVaultStQEURO();
        _phaseC_userPoolHedgerPool();
        _phaseD_yieldShiftWiring();
    }

    // ------------------------ Phase A ------------------------

    function _phaseA_timeProviderOracleQeuroFeeCollectorVault() internal {
        // Mock USDC + balances
        usdc = new MockUSDC();
        usdc.mint(user1, INITIAL_USDC_AMOUNT);
        usdc.mint(hedger1, INITIAL_USDC_AMOUNT);

        // Chainlink feeds
        eurUsdFeed = new MockAggregatorV3(8);
        eurUsdFeed.setPrice(int256(EUR_USD_PRICE));
        usdcUsdFeed = new MockAggregatorV3(8);
        usdcUsdFeed.setPrice(int256(USDC_USD_PRICE));

        // TimeProvider
        TimeProvider timeImpl = new TimeProvider();
        bytes memory timeInit = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProxy = new ERC1967Proxy(address(timeImpl), timeInit);
        timeProvider = TimeProvider(address(timeProxy));

        // Oracle
        MockChainlinkOracle oracleImpl = new MockChainlinkOracle();
        bytes memory oracleInit = abi.encodeWithSelector(
            MockChainlinkOracle.initialize.selector,
            admin,
            address(eurUsdFeed),
            address(usdcUsdFeed),
            treasury
        );
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), oracleInit);
        // MockChainlinkOracle has a payable receive/fallback, so cast via address payable
        oracle = MockChainlinkOracle(payable(address(oracleProxy)));

        vm.prank(admin);
        oracle.setPrices(1.10e18, 1.00e18);

        // FeeCollector
        FeeCollector feeImpl = new FeeCollector();
        bytes memory feeInit = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury,
            treasury,
            treasury
        );
        ERC1967Proxy feeProxy = new ERC1967Proxy(address(feeImpl), feeInit);
        feeCollector = FeeCollector(address(feeProxy));

        // QEURO (vault address filled later)
        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroInit = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            address(0),
            timelock,
            treasury,
            address(feeCollector)
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImpl), qeuroInit);
        qeuroToken = QEUROToken(address(qeuroProxy));

        // Vault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInit = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuroToken),
            address(usdc),
            address(oracle),
            address(0), // hedgerPool later
            address(0), // userPool later
            timelock,
            address(feeCollector)
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInit);
        vault = QuantillonVault(address(vaultProxy));

        // Allow vault to mint/burn QEURO
        vm.startPrank(admin);
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), address(vault));
        qeuroToken.grantRole(qeuroToken.BURNER_ROLE(), address(vault));
        vm.stopPrank();
    }

    // ------------------------ Phase B ------------------------

    function _phaseB_qtiAaveVaultStQEURO() internal {
        // QTI
        QTIToken qtiImpl = new QTIToken(timeProvider);
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiImpl), bytes(""));
        qtiToken = QTIToken(address(qtiProxy));
        qtiToken.initialize(admin, treasury, timelock);

        // YieldShift placeholder (wired in Phase D but deployed here so stQEURO can reference it)
        YieldShift ysImpl = new YieldShift(timeProvider);
        bytes memory ysInit = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            admin,
            address(usdc),
            address(0), // userPool
            address(0), // hedgerPool
            address(0), // aaveVault
            address(0), // stQEURO
            timelock,
            treasury
        );
        ERC1967Proxy ysProxy = new ERC1967Proxy(address(ysImpl), ysInit);
        yieldShift = YieldShift(address(ysProxy));

        // stQEURO
        stQEUROToken stImpl = new stQEUROToken(timeProvider);
        bytes memory stInit = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            address(qeuroToken),
            address(yieldShift),
            address(usdc),
            treasury,
            timelock
        );
        ERC1967Proxy stProxy = new ERC1967Proxy(address(stImpl), stInit);
        stQEURO = stQEUROToken(address(stProxy));
    }

    // ------------------------ Phase C ------------------------

    function _phaseC_userPoolHedgerPool() internal {
        // UserPool
        UserPool userImpl = new UserPool(timeProvider);
        bytes memory userInit = abi.encodeWithSelector(
            UserPool.initialize.selector,
            admin,
            address(usdc),
            address(qeuroToken),
            address(stQEURO),
            address(yieldShift),
            treasury,
            100,   // depositFee (1%)
            100,   // stakingFee (1%)
            86400  // unstaking cooldown
        );
        ERC1967Proxy userProxy = new ERC1967Proxy(address(userImpl), userInit);
        userPool = UserPool(address(userProxy));

        // HedgerPool
        HedgerPool hedgerImpl = new HedgerPool(timeProvider);
        bytes memory hedgerInit = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            admin,
            address(usdc),
            address(oracle),
            address(yieldShift),
            timelock,
            treasury,
            address(vault)
        );
        ERC1967Proxy hedgerProxy = new ERC1967Proxy(address(hedgerImpl), hedgerInit);
        hedgerPool = HedgerPool(address(hedgerProxy));

        // Basic roles for smoke
        vm.startPrank(admin);
        userPool.grantRole(userPool.GOVERNANCE_ROLE(), governance);
        userPool.grantRole(userPool.EMERGENCY_ROLE(), emergency);
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), emergency);
        vault.grantRole(vault.GOVERNANCE_ROLE(), governance);
        vault.grantRole(vault.EMERGENCY_ROLE(), emergency);
        vm.stopPrank();
    }

    // ------------------------ Phase D ------------------------

    function _phaseD_yieldShiftWiring() internal {
        vm.startPrank(admin);
        // Wire pools into vault
        vault.updateHedgerPool(address(hedgerPool));
        vault.updateUserPool(address(userPool));

        // Wire pools + aave into YieldShift
        yieldShift.updateUserPool(address(userPool));
        yieldShift.updateHedgerPool(address(hedgerPool));
        // Note: aaveVault integration can be extended here when mocks are richer
        vm.stopPrank();
    }

    // ------------------------ Smoke test ------------------------

    /// @notice End‑to‑end smoke test: deploy, then run minimal flows.
    /// @dev Temporarily disabled until dedicated Aave mocks are wired.
    function xtest_DeploymentSmoke_BasicFlows_DisabledForNow() public {
        deployFullProtocol();

        // Sanity: key contracts are deployed
        assertTrue(address(timeProvider) != address(0), "TimeProvider not deployed");
        assertTrue(address(qeuroToken) != address(0), "QEURO not deployed");
        assertTrue(address(qtiToken) != address(0), "QTI not deployed");
        assertTrue(address(vault) != address(0), "Vault not deployed");
        assertTrue(address(userPool) != address(0), "UserPool not deployed");
        assertTrue(address(hedgerPool) != address(0), "HedgerPool not deployed");
        assertTrue(address(stQEURO) != address(0), "stQEURO not deployed");
        assertTrue(address(yieldShift) != address(0), "YieldShift not deployed");

        // --- Minimal user deposit + mint + redeem through vault ---
        vm.startPrank(user1);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);

        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");

        uint256 expectedQeuro = (DEPOSIT_AMOUNT * 1e12) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQeuro * 99) / 100);

        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        assertGt(qeuroBal, 0, "QEURO should be minted");

        // Redeem all back to USDC
        uint256 usdcBefore = usdc.balanceOf(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        uint256 expectedUsdc = (qeuroBal * eurPrice) / 1e18;
        uint256 minUsdcOut = (expectedUsdc * 99) / 100;
        vault.redeemQEURO(qeuroBal, minUsdcOut);
        uint256 usdcAfter = usdc.balanceOf(user1);
        vm.stopPrank();

        assertGt(usdcAfter, usdcBefore, "User should receive USDC on redeem");

        // --- Minimal staking + unstaking roundtrip ---
        // Give user some QEURO again via another mint
        vm.startPrank(user1);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQeuro * 99) / 100);
        uint256 qeuroForStake = qeuroToken.balanceOf(user1) / 2;

        qeuroToken.approve(address(stQEURO), qeuroForStake);
        uint256 stAmount = stQEURO.stake(qeuroForStake);
        assertGt(stAmount, 0, "stQEURO should be minted");

        uint256 qeuroBack = stQEURO.unstake(stAmount);
        assertGt(qeuroBack, 0, "Unstake should return QEURO");
        vm.stopPrank();

        // --- Basic QTI governance sanity: roles and getters ---
        (uint256 totalLocked,, uint256 proposalThreshold,, uint256 decLevel) = qtiToken.getGovernanceInfo();
        // Just check getters are callable and initial values are sensible
        assertEq(totalLocked, 0, "Initial locked QTI should be 0");
        assertGt(proposalThreshold, 0, "Proposal threshold should be > 0");
        assertEq(decLevel, 0, "Initial decentralization level should be 0");
    }
}

