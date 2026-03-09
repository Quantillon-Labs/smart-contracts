// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

contract FixedOracle {
    uint256 public eurUsdPrice = 1e18;
    uint256 public usdcUsdPrice = 1e18;

    function setPrices(uint256 eurUsd, uint256 usdcUsd) external {
        eurUsdPrice = eurUsd;
        usdcUsdPrice = usdcUsd;
    }

    function getEurUsdPrice() external view returns (uint256 price, bool isValid) {
        return (eurUsdPrice, true);
    }

    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid) {
        return (usdcUsdPrice, true);
    }
}

contract HedgerPoolHarness {
    IERC20 public immutable usdc;
    QuantillonVault public immutable vault;
    uint256 public totalMargin;

    constructor(IERC20 _usdc, QuantillonVault _vault) {
        usdc = _usdc;
        vault = _vault;
    }

    function seedMargin(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(vault), amount);
        totalMargin += amount;
        vault.addHedgerDeposit(amount);
    }

    function recordUserMint(uint256, uint256, uint256) external {}

    function recordUserRedeem(uint256, uint256, uint256) external {}

    function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external {
        if (totalQeuroSupply == 0 || totalMargin == 0) return;
        uint256 marginLoss = (qeuroAmount * totalMargin) / totalQeuroSupply;
        if (marginLoss > totalMargin) marginLoss = totalMargin;
        totalMargin -= marginLoss;
    }

    function getTotalEffectiveHedgerCollateral(uint256) external view returns (uint256) {
        return totalMargin;
    }

    function hasActiveHedger() external view returns (bool) {
        return totalMargin > 0;
    }

    function fundRewardReserve(uint256) external {}
}

contract QuantillonVaultMintCollateralizationAndLiquidationThresholdTest is Test {
    address internal admin = address(0xA11CE);
    address internal hedger = address(0xBEEF01);
    address internal bootstrapUser = address(0xB007);
    address internal attacker = address(0xBAD);

    MockUSDC internal usdc;
    QEUROToken internal qeuro;
    QuantillonVault internal vault;
    FixedOracle internal oracle;
    HedgerPoolHarness internal hedgerPool;

    function setUp() public {
        usdc = new MockUSDC();
        oracle = new FixedOracle();

        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroInit = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            address(0x1111), // placeholder vault
            address(0x2222), // placeholder timelock
            admin,           // treasury
            address(0x3333)  // fee collector
        );
        qeuro = QEUROToken(address(new ERC1967Proxy(address(qeuroImpl), qeuroInit)));

        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInit = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuro),
            address(usdc),
            address(oracle),
            address(0),      // hedgerPool wired later
            address(0x4444), // non-zero userPool placeholder
            address(0x5555), // timelock
            address(0x6666)  // fee collector
        );
        vault = QuantillonVault(address(new ERC1967Proxy(address(vaultImpl), vaultInit)));

        hedgerPool = new HedgerPoolHarness(IERC20(address(usdc)), vault);

        vm.startPrank(admin);
        qeuro.grantRole(qeuro.MINTER_ROLE(), address(vault));
        qeuro.grantRole(qeuro.BURNER_ROLE(), address(vault));
        vault.updateHedgerPool(address(hedgerPool));
        vault.initializePriceCache();
        vm.stopPrank();

        usdc.mint(hedger, 1_000_000e6);
        usdc.mint(bootstrapUser, 10_000e6);
        usdc.mint(attacker, 2_000_000e6);
    }

    function test_PostMintCollateralizationCheck_BlocksMarginExtractionExploit() public {
        uint256 hedgerMargin = 50e6; // 50 USDC
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        // Bootstrap at exactly 105% CR: 1,000 USDC user collateral + 50 USDC hedger margin
        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);

        // Large one-shot mint is allowed because canMint() checks only PRE-mint CR.
        uint256 attackerDeposit = 1_000_000e6;
        uint256 attackerUsdcBefore = usdc.balanceOf(attacker);

        vm.prank(attacker);
        usdc.approve(address(vault), attackerDeposit);
        vm.prank(attacker);
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        vault.mintQEURO(attackerDeposit, 0);

        uint256 attackerUsdcAfter = usdc.balanceOf(attacker);
        assertEq(attackerUsdcAfter, attackerUsdcBefore, "attacker should not be able to execute exploit path");
    }

    function test_CriticalThresholdConfig_DrivesLiquidationRouting() public {
        // Lower critical threshold to 100% (while keeping mint threshold at 101%).
        vm.prank(admin);
        vault.updateCollateralizationThresholds(101e18, 100e18);

        // Build a 101% CR state: 1,000 USDC user collateral + 10 USDC hedger margin.
        uint256 hedgerMargin = 10e6;
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);

        uint256 usdcBefore = usdc.balanceOf(bootstrapUser);

        // At CR = 101% and critical = 100%, redemption should stay in normal mode.
        // Normal mode payout for 100 QEURO at price 1.0 is exactly 100 USDC.
        uint256 redeemAmount = 100e18;
        vm.prank(bootstrapUser);
        vault.redeemQEURO(redeemAmount, 0);

        uint256 usdcAfter = usdc.balanceOf(bootstrapUser);
        uint256 received = usdcAfter - usdcBefore;
        assertEq(received, 100e6, "redeem should use normal mode when CR > configured critical threshold");
    }
}
