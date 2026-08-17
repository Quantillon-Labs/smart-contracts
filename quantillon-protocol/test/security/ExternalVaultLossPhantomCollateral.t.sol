// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {MockUSDC, MockOracle, MockHedgerPool, MockAaveVault} from "../AaveIntegration.t.sol";
import {QuantillonVault} from "../../src/core/QuantillonVault.sol";
import {UserPool} from "../../src/core/UserPool.sol";
import {QEUROToken} from "../../src/core/QEUROToken.sol";
import {FeeCollector} from "../../src/core/FeeCollector.sol";
import {MetaMorphoStakingVaultAdapter} from "../../src/core/vaults/MetaMorphoStakingVaultAdapter.sol";
import {CommonErrorLibrary} from "../../src/libraries/CommonErrorLibrary.sol";
import {TimeProvider} from "../../src/libraries/TimeProviderLibrary.sol";

/// @dev Loss is reported by an independent strategy actor, never by either QEURO holder.
contract LossRealizingERC4626 is ERC4626 {
    using SafeERC20 for IERC20;

    error NotStrategy();

    address public immutable strategy;
    address public immutable lossSink;

    constructor(IERC20 asset_, address strategy_, address lossSink_)
        ERC20("Loss-realizing USDC vault", "lossUSDC")
        ERC4626(asset_)
    {
        strategy = strategy_;
        lossSink = lossSink_;
    }

    function realizeStrategyLoss(uint256 assets) external {
        if (msg.sender != strategy) revert NotStrategy();
        IERC20(asset()).safeTransfer(lossSink, assets);
    }
}

/// @title ExternalVaultLossPhantomCollateral regression suite
/// @notice Regression guard for QNT-EXTERNAL-LOSS-PHANTOM-COLLATERAL. QuantillonVault must value
///         external ERC-4626 positions loss-aware, i.e. at min(trackedPrincipal, adapterUnderlying).
///         Before the fix (<= v1.1.10), collateral counted stale principal only, so an external loss
///         (a) left reported collateral unchanged, (b) let the first redeemer exit at par and shift
///         the shortfall onto later redeemers, and (c) admitted QEURO mints below the collateral
///         floor. These tests assert the corrected, loss-aware behavior and FAIL if the phantom
///         accounting is reintroduced.
contract ExternalVaultLossPhantomCollateralRegression is Test {
    address internal constant ALICE = address(0xA11CE);
    address internal constant MALLORY = address(0xB0B);
    address internal constant STRATEGY = address(0x5157);
    address internal constant LOSS_SINK = address(0xDEAD);

    address internal constant ADMIN = address(0x1);
    address internal constant TREASURY = address(0x3);

    QuantillonVault internal vault;
    UserPool internal userPool;
    QEUROToken internal qeuro;
    MockUSDC internal usdc;
    MockOracle internal oracle;
    MockHedgerPool internal hedgerPool;
    FeeCollector internal feeCollector;
    TimeProvider internal timeProvider;

    function setUp() public {
        vm.startPrank(ADMIN);

        usdc = new MockUSDC();
        oracle = new MockOracle();
        hedgerPool = new MockHedgerPool();
        timeProvider = new TimeProvider();

        FeeCollector feeCollectorImplementation = new FeeCollector();
        bytes memory feeCollectorData =
            abi.encodeWithSelector(FeeCollector.initialize.selector, ADMIN, TREASURY, TREASURY, TREASURY);
        feeCollector = FeeCollector(address(new ERC1967Proxy(address(feeCollectorImplementation), feeCollectorData)));

        QEUROToken qeuroImplementation = new QEUROToken();
        bytes memory qeuroData = abi.encodeWithSelector(
            QEUROToken.initialize.selector, ADMIN, ADMIN, TREASURY, TREASURY, address(feeCollector)
        );
        qeuro = QEUROToken(address(new ERC1967Proxy(address(qeuroImplementation), qeuroData)));

        QuantillonVault vaultImplementation = new QuantillonVault();
        bytes memory vaultData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            ADMIN,
            address(qeuro),
            address(usdc),
            address(oracle),
            address(hedgerPool),
            address(0),
            TREASURY,
            address(feeCollector)
        );
        vault = QuantillonVault(address(new ERC1967Proxy(address(vaultImplementation), vaultData)));

        UserPool userPoolImplementation = new UserPool(timeProvider);
        bytes memory userPoolData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            ADMIN,
            address(qeuro),
            address(usdc),
            address(vault),
            address(oracle),
            address(0),
            TREASURY,
            TREASURY
        );
        userPool = UserPool(address(new ERC1967Proxy(address(userPoolImplementation), userPoolData)));

        MockAaveVault bootstrapAdapter = new MockAaveVault(address(usdc));
        vault.setStakingVault(1, address(bootstrapAdapter), true);
        vault.setDefaultStakingVaultId(1);
        uint256[] memory redemptionPriority = new uint256[](1);
        redemptionPriority[0] = 1;
        vault.setRedemptionPriority(redemptionPriority);
        vault.updateUserPool(address(userPool));
        vault.grantRole(vault.VAULT_OPERATOR_ROLE(), address(userPool));
        qeuro.grantRole(qeuro.MINTER_ROLE(), address(vault));
        qeuro.grantRole(qeuro.BURNER_ROLE(), address(vault));
        feeCollector.grantRole(feeCollector.TREASURY_ROLE(), address(vault));

        vault.proposeDevMode(true);
        vm.warp(block.timestamp + 48 hours + 1);
        vm.roll(block.number + 14_401);
        vault.applyDevMode();
        vault.initializePriceCache(108e16);

        usdc.mint(address(vault), 2_000e6);
        vm.stopPrank();

        vm.prank(address(hedgerPool));
        vault.addHedgerDeposit(2_000e6);
    }

    function _installLossRealizingVault()
        internal
        returns (LossRealizingERC4626 externalVault, MetaMorphoStakingVaultAdapter adapter)
    {
        externalVault = new LossRealizingERC4626(IERC20(address(usdc)), STRATEGY, LOSS_SINK);
        adapter = new MetaMorphoStakingVaultAdapter(address(vault), address(usdc), address(externalVault));

        vm.prank(ADMIN);
        vault.setStakingVault(1, address(adapter), true);
    }

    function _mintToExternalVault(address holder, uint256 usdcAmount) internal {
        usdc.mint(holder, usdcAmount);
        vm.startPrank(holder);
        usdc.approve(address(vault), type(uint256).max);
        vault.mintQEUROToVault(usdcAmount, 0, 1);
        vm.stopPrank();
    }

    function _realizeLoss(LossRealizingERC4626 externalVault, uint256 loss) internal {
        vm.prank(STRATEGY);
        externalVault.realizeStrategyLoss(loss);
    }

    function _actualCollateral() internal view returns (uint256) {
        (,,, uint256 actualExternalAssets) = vault.getVaultExposure(1);
        return vault.totalUsdcHeld() + actualExternalAssets;
    }

    // -------------------------------------------------------------------------
    // Controls (behavior that must be unaffected by the fix)
    // -------------------------------------------------------------------------

    function test_control_malloryCannotCauseTheExternalLoss() public {
        (LossRealizingERC4626 externalVault,) = _installLossRealizingVault();

        vm.prank(MALLORY);
        vm.expectRevert(LossRealizingERC4626.NotStrategy.selector);
        externalVault.realizeStrategyLoss(1);
    }

    function test_control_withoutLossBothHoldersRedeemInFull() public {
        _installLossRealizingVault();
        _mintToExternalVault(ALICE, 5_400e6);
        _mintToExternalVault(MALLORY, 5_400e6);

        // Read balances before pranking: an external call in the argument list would otherwise
        // consume vm.prank and run redeemQEURO as this test contract instead of the holder.
        uint256 malloryBefore = usdc.balanceOf(MALLORY);
        uint256 malloryQeuro = qeuro.balanceOf(MALLORY);
        vm.prank(MALLORY);
        vault.redeemQEURO(malloryQeuro, 0);

        uint256 aliceBefore = usdc.balanceOf(ALICE);
        uint256 aliceQeuro = qeuro.balanceOf(ALICE);
        vm.prank(ALICE);
        vault.redeemQEURO(aliceQeuro, 0);

        assertEq(usdc.balanceOf(MALLORY) - malloryBefore, 5_400e6, "Mallory exits in full when there is no loss");
        assertEq(usdc.balanceOf(ALICE) - aliceBefore, 5_400e6, "Alice exits in full when there is no loss");
    }

    // -------------------------------------------------------------------------
    // Fixed behavior
    // -------------------------------------------------------------------------

    /// @notice An external loss lowers reported collateral immediately (no phantom principal).
    function test_lossImmediatelyReducesReportedCollateral() public {
        (LossRealizingERC4626 externalVault,) = _installLossRealizingVault();
        _mintToExternalVault(ALICE, 10_800e6);

        assertEq(vault.getTotalUsdcAvailable(), 12_800e6, "pre-loss collateral = held + principal");

        _realizeLoss(externalVault, 4_000e6);

        (,, uint256 principalAfterLoss, uint256 underlyingAfterLoss) = vault.getVaultExposure(1);
        assertEq(principalAfterLoss, 10_800e6, "principal tracker is unchanged by the loss");
        assertEq(underlyingAfterLoss, 6_800e6, "adapter reports the reduced share value");

        // Fixed: collateral is valued at min(principal, underlying), so the 4000 loss is reflected.
        assertEq(vault.getTotalUsdcAvailable(), 8_800e6, "reported collateral drops by the loss");
        assertEq(vault.getTotalUsdcAvailable(), _actualCollateral(), "no phantom gap remains");
    }

    /// @notice After a loss, the first redeemer gets only their fair pro-rata share; the second
    ///         holder can still redeem their equal share. No value is shifted between holders.
    function test_firstRedeemerCannotTakeValueFromSecondHolder() public {
        (LossRealizingERC4626 externalVault,) = _installLossRealizingVault();
        _mintToExternalVault(ALICE, 5_400e6);
        _mintToExternalVault(MALLORY, 5_400e6);

        _realizeLoss(externalVault, 4_000e6);

        uint256 actualCollateral = _actualCollateral();
        uint256 totalQeuroBefore = qeuro.totalSupply();
        uint256 malloryQeuro = qeuro.balanceOf(MALLORY);
        uint256 fairProRata = malloryQeuro * actualCollateral / totalQeuroBefore;

        assertEq(vault.getTotalUsdcAvailable(), 8_800e6, "reported collateral reflects the loss");
        assertEq(actualCollateral, 8_800e6, "actual collateral after the loss");
        assertEq(fairProRata, 4_400e6, "fair pro-rata share for an equal holder");

        uint256 malloryBefore = usdc.balanceOf(MALLORY);
        vm.prank(MALLORY);
        vault.redeemQEURO(malloryQeuro, 0);
        uint256 malloryPayout = usdc.balanceOf(MALLORY) - malloryBefore;

        assertEq(malloryPayout, fairProRata, "first redeemer receives exactly the fair pro-rata amount");
        assertEq(malloryPayout, 4_400e6, "no par exit against a depleted position");

        // The second holder is not stranded: an equal position still redeems its equal share.
        uint256 aliceQeuro = qeuro.balanceOf(ALICE);
        uint256 aliceBefore = usdc.balanceOf(ALICE);
        vm.prank(ALICE);
        vault.redeemQEURO(aliceQeuro, 0);
        uint256 alicePayout = usdc.balanceOf(ALICE) - aliceBefore;

        assertEq(alicePayout, 4_400e6, "second holder redeems the same fair share");
        assertEq(malloryPayout + alicePayout, actualCollateral, "holders split the real collateral, nothing shifted");
    }

    /// @notice A mint that would leave real backing below the mint floor is rejected after a loss.
    function test_undercollateralizedMintIsBlocked() public {
        (LossRealizingERC4626 externalVault,) = _installLossRealizingVault();
        _mintToExternalVault(ALICE, 10_800e6);
        _realizeLoss(externalVault, 4_000e6);

        assertEq(vault.getTotalUsdcAvailable(), 8_800e6, "collateral reflects the loss before the mint attempt");
        assertEq(vault.getTotalUsdcAvailable(), _actualCollateral(), "no phantom collateral before the mint attempt");

        usdc.mint(MALLORY, 5_400e6);
        vm.startPrank(MALLORY);
        usdc.approve(address(vault), type(uint256).max);
        // Fixed: the mint floor now sees real (loss-aware) collateral and rejects the mint.
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        vault.mintQEUROToVault(5_400e6, 0, 1);
        vm.stopPrank();
    }

    /// @notice Redemption order confers no advantage across a range of loss sizes and both orderings.
    function testFuzz_redeemOrderDoesNotCreateAdvantage(uint96 rawLoss, bool malloryFirst) public {
        uint256 loss = bound(uint256(rawLoss), 2_100e6, 5_000e6);
        (LossRealizingERC4626 externalVault,) = _installLossRealizingVault();
        _mintToExternalVault(ALICE, 5_400e6);
        _mintToExternalVault(MALLORY, 5_400e6);
        _realizeLoss(externalVault, loss);

        uint256 actualCollateral = _actualCollateral();
        assertEq(vault.getTotalUsdcAvailable(), actualCollateral, "reported collateral reflects the loss");

        address first = malloryFirst ? MALLORY : ALICE;
        address second = malloryFirst ? ALICE : MALLORY;
        uint256 firstQeuro = qeuro.balanceOf(first);
        uint256 fairProRata = firstQeuro * actualCollateral / qeuro.totalSupply();

        uint256 firstBefore = usdc.balanceOf(first);
        vm.prank(first);
        vault.redeemQEURO(firstQeuro, 0);
        uint256 firstPayout = usdc.balanceOf(first) - firstBefore;

        assertEq(firstPayout, fairProRata, "first redeemer gets exactly the fair share, no ordering advantage");

        // The second holder is never blocked with InsufficientBalance and is never worse off.
        uint256 secondQeuro = qeuro.balanceOf(second);
        uint256 secondBefore = usdc.balanceOf(second);
        vm.prank(second);
        vault.redeemQEURO(secondQeuro, 0);
        uint256 secondPayout = usdc.balanceOf(second) - secondBefore;

        assertGe(secondPayout, firstPayout, "the later redeemer is never worse off than the first");
        assertEq(firstPayout + secondPayout, actualCollateral, "the two holders split the real collateral exactly");
    }

    /// @notice Across loss sizes, collateral always tracks the real value and blocks an unsafe mint.
    function testFuzz_lossReducesCollateralAndBlocksUndercollateralizedMint(uint96 rawLoss) public {
        uint256 loss = bound(uint256(rawLoss), 2_100e6, 8_000e6);
        (LossRealizingERC4626 externalVault,) = _installLossRealizingVault();
        _mintToExternalVault(ALICE, 10_800e6);
        _realizeLoss(externalVault, loss);

        assertEq(vault.getTotalUsdcAvailable(), 12_800e6 - loss, "reported collateral reflects every tested loss size");
        assertEq(vault.getTotalUsdcAvailable(), _actualCollateral(), "no phantom collateral for any loss size");

        usdc.mint(MALLORY, 5_400e6);
        vm.startPrank(MALLORY);
        usdc.approve(address(vault), type(uint256).max);
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        vault.mintQEUROToVault(5_400e6, 0, 1);
        vm.stopPrank();
    }
}
