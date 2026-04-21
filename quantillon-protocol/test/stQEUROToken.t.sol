// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

contract MockQEUROAsset is ERC20 {
    constructor() ERC20("Mock QEURO", "mQEURO") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract stQEUROTokenTestSuite is Test {
    MockQEUROAsset internal qeuro;
    TimeProvider internal timeProvider;
    stQEUROToken internal implementation;
    stQEUROToken internal stQEURO;

    address internal admin = address(0xA11CE);
    address internal treasury = address(0xBEEF);
    address internal timelock = address(0xCAFE);
    address internal user1 = address(0x1111);
    address internal user2 = address(0x2222);

    uint256 internal constant DEPOSIT_AMOUNT = 100e18;
    uint256 internal constant DONATION_AMOUNT = 20e18;

    function setUp() public {
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));

        qeuro = new MockQEUROAsset();
        implementation = new stQEUROToken(timeProvider);

        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address,address,address,address,string)")),
            admin,
            address(qeuro),
            treasury,
            timelock,
            "AAVE"
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        stQEURO = stQEUROToken(address(proxy));

        qeuro.mint(user1, 1_000e18);
        qeuro.mint(user2, 1_000e18);
    }

    function testInitialization_WithVaultMetadata_ShouldInitializeCorrectly() public view {
        assertEq(stQEURO.asset(), address(qeuro));
        assertEq(address(stQEURO.qeuro()), address(qeuro));
        assertEq(stQEURO.name(), "Staked Quantillon Euro AAVE");
        assertEq(stQEURO.symbol(), "stQEUROAAVE");
        assertEq(stQEURO.vaultName(), "AAVE");
        assertEq(stQEURO.treasury(), treasury);
        assertEq(stQEURO.yieldFee(), 0);
    }

    function testInitialize_LegacySignatureStillBootstrapsAssetVault() public {
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address,address,address,address,address,address)")),
            admin,
            address(qeuro),
            address(0x1),
            address(0x2),
            treasury,
            timelock
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        stQEUROToken legacy = stQEUROToken(address(proxy));

        assertEq(legacy.asset(), address(qeuro));
        assertEq(legacy.name(), "Staked Quantillon Euro");
        assertEq(legacy.symbol(), "stQEURO");
        assertEq(legacy.vaultName(), "");
    }

    function testDepositAndRedeem_RoundTrip_ShouldMatchPreview() public {
        vm.startPrank(user1);
        qeuro.approve(address(stQEURO), DEPOSIT_AMOUNT);

        uint256 previewShares = stQEURO.previewDeposit(DEPOSIT_AMOUNT);
        uint256 mintedShares = stQEURO.deposit(DEPOSIT_AMOUNT, user1);
        assertEq(mintedShares, previewShares);
        assertEq(mintedShares, DEPOSIT_AMOUNT);
        assertEq(stQEURO.totalAssets(), DEPOSIT_AMOUNT);
        assertEq(stQEURO.balanceOf(user1), mintedShares);

        uint256 previewAssets = stQEURO.previewRedeem(mintedShares);
        uint256 redeemedAssets = stQEURO.redeem(mintedShares, user1, user1);
        vm.stopPrank();

        assertEq(redeemedAssets, previewAssets);
        assertEq(redeemedAssets, DEPOSIT_AMOUNT);
        assertEq(stQEURO.totalAssets(), 0);
        assertEq(stQEURO.balanceOf(user1), 0);
    }

    function testDonationYield_IncreasesShareValueWithoutMintingShares() public {
        vm.startPrank(user1);
        qeuro.approve(address(stQEURO), DEPOSIT_AMOUNT);
        uint256 shares = stQEURO.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        uint256 supplyBefore = stQEURO.totalSupply();
        qeuro.mint(address(stQEURO), DONATION_AMOUNT);

        assertEq(stQEURO.totalSupply(), supplyBefore);
        assertEq(stQEURO.totalAssets(), DEPOSIT_AMOUNT + DONATION_AMOUNT);
        assertGt(stQEURO.convertToAssets(shares), DEPOSIT_AMOUNT);
        assertApproxEqAbs(stQEURO.previewRedeem(shares), DEPOSIT_AMOUNT + DONATION_AMOUNT, 1);
    }

    function testPreviewWithdrawAndRedeem_ReflectCurrentVaultBacking() public {
        vm.startPrank(user1);
        qeuro.approve(address(stQEURO), DEPOSIT_AMOUNT);
        uint256 shares = stQEURO.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        qeuro.mint(address(stQEURO), DONATION_AMOUNT);

        uint256 assetsOut = 60e18;
        uint256 previewShares = stQEURO.previewWithdraw(assetsOut);
        uint256 previewAssets = stQEURO.previewRedeem(shares / 2);

        assertGt(previewAssets, shares / 2);
        assertGt(previewShares, 0);
    }

    function testPause_BlocksTransfersAndVaultOperations() public {
        vm.startPrank(user1);
        qeuro.approve(address(stQEURO), DEPOSIT_AMOUNT);
        stQEURO.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        vm.prank(admin);
        stQEURO.pause();

        vm.startPrank(user1);
        vm.expectRevert();
        stQEURO.transfer(user2, 1e18);

        vm.expectRevert();
        stQEURO.redeem(1e18, user1, user1);
        vm.stopPrank();

        assertEq(stQEURO.maxDeposit(user1), 0);
        assertEq(stQEURO.maxMint(user1), 0);
        assertEq(stQEURO.maxWithdraw(user1), 0);
        assertEq(stQEURO.maxRedeem(user1), 0);
    }

    function testEmergencyWithdraw_WhenPaused_ReturnsUnderlyingToUser() public {
        vm.startPrank(user1);
        qeuro.approve(address(stQEURO), DEPOSIT_AMOUNT);
        uint256 shares = stQEURO.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        qeuro.mint(address(stQEURO), DONATION_AMOUNT);

        vm.prank(admin);
        stQEURO.pause();

        uint256 userBalanceBefore = qeuro.balanceOf(user1);
        vm.prank(admin);
        stQEURO.emergencyWithdraw(user1);

        assertEq(stQEURO.balanceOf(user1), 0);
        assertEq(stQEURO.totalSupply(), 0);
        assertApproxEqAbs(qeuro.balanceOf(user1) - userBalanceBefore, DEPOSIT_AMOUNT + DONATION_AMOUNT, 1);
        assertEq(shares, DEPOSIT_AMOUNT);
    }

    function testUpdateYieldParameters_ShouldUpdateYieldFee() public {
        vm.prank(admin);
        stQEURO.updateYieldParameters(500);

        assertEq(stQEURO.yieldFee(), 500);
    }

    function testUpdateYieldParameters_ShouldRevertAboveCap() public {
        vm.prank(admin);
        vm.expectRevert();
        stQEURO.updateYieldParameters(2500);
    }

    function testUpdateTreasury_ShouldUpdateTreasury() public {
        address newTreasury = address(0xD00D);

        vm.prank(admin);
        stQEURO.updateTreasury(newTreasury);

        assertEq(stQEURO.treasury(), newTreasury);
    }

    function testRecoverToken_ShouldRejectVaultAsset() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InvalidToken.selector);
        stQEURO.recoverToken(address(qeuro), 1);
    }
}
