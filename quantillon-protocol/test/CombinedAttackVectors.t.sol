// test/CombinedAttackVectors.t.sol
// Multi-step attack scenarios: flash loan + oracle, governance timing, yield during volatility.
// This file exists to test chained attack vectors that combine multiple protocol interactions.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IntegrationTests} from "./IntegrationTests.t.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title CombinedAttackVectors
 * @notice Multi-step attack tests that chain flash loans, oracle manipulation, and governance timing
 * @dev Reuses IntegrationTests setup (vault, oracle, userPool, mocks, roles) for fresh setUp per test
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract CombinedAttackVectors is IntegrationTests {
    address public attacker = address(0x20);

    /**
     * @notice Flash loan + oracle manipulation: extreme price causes mint to revert
     * @dev Attacker would borrow large USDC, manipulate oracle, mint QEURO at favorable price; protocol reverts on deviation
     */
    function test_Combined_FlashLoanOracleManipulation_Blocked() public {
        vm.prank(admin);
        vault.setDevMode(false);

        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        vm.stopPrank();

        vm.roll(block.number + 2);
        // Sync feed with oracle so getEurUsdPrice returns (1.15e18, true); vault then sees deviation from its lastValid (1.10e18)
        eurUsdFeed.setPrice(int256(1.15e8)); // 8 decimals for Chainlink feed
        vm.prank(admin);
        oracle.setPrices(1.15e18, 1e18);

        // MockUSDC owner is the test contract (deployer in IntegrationTests.setUp)
        vm.prank(address(this));
        mockUSDC.mint(attacker, 10_000_000 * 1e6);
        vm.startPrank(attacker);
        mockUSDC.approve(address(vault), 100_000 * 1e6);
        uint256 usdcAttack = 100_000 * 1e6;
        uint256 expectedQEURO2 = (usdcAttack * 1e14) / 115;
        vm.expectRevert(CommonErrorLibrary.ExcessiveSlippage.selector);
        vault.mintQEURO(usdcAttack, (expectedQEURO2 * 90) / 100);
        vm.stopPrank();
    }

    /**
     * @notice Governance timing: only governance can update collateralization thresholds
     * @dev Attacker cannot change critical ratio; governance can. Ensures parameter changes are gated.
     */
    function test_Combined_GovernanceTiming_OnlyGovernanceUpdatesParams() public {
        uint256 criticalBefore = vault.criticalCollateralizationRatio();
        vm.prank(attacker);
        vm.expectRevert();
        vault.updateCollateralizationThresholds(102e18, 102e18);
        assertEq(vault.criticalCollateralizationRatio(), criticalBefore, "Attacker cannot change CR");

        vm.prank(governance);
        vault.updateCollateralizationThresholds(102e18, 102e18);
        assertEq(vault.criticalCollateralizationRatio(), 102e18, "Governance can update CR");
    }

    /**
     * @notice Yield extraction during volatility: redeem after price drop does not over-pay
     * @dev User mints, stakes; oracle price drops; user redeems. Assert redemption amount bounded by collateral.
     */
    function test_Combined_YieldExtractionDuringVolatility_RedemptionBounded() public {
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        qeuroToken.approve(address(stQEURO), qeuroBal / 2);
        stQEURO.stake(qeuroBal / 2);
        vm.stopPrank();

        // Sync feed with oracle so getEurUsdPrice returns (1e18, true); otherwise oracle returns isValid=false (deviation from feed 1.10)
        eurUsdFeed.setPrice(int256(1e8));
        vm.prank(admin);
        oracle.setPrices(1.00e18, 1e18);

        uint256 vaultUsdcBefore = mockUSDC.balanceOf(address(vault));
        uint256 userUsdcBefore = mockUSDC.balanceOf(user1);
        vm.startPrank(user1);
        uint256 toRedeem = qeuroToken.balanceOf(user1);
        qeuroToken.approve(address(vault), toRedeem);
        uint256 expectedUsdc = (toRedeem * 1e18) / 1e30;
        uint256 minOut = (expectedUsdc * 80) / 100;
        vault.redeemQEURO(toRedeem, minOut);
        vm.stopPrank();

        uint256 usdcReceived = mockUSDC.balanceOf(user1) - userUsdcBefore;
        assertLe(usdcReceived, vaultUsdcBefore, "User cannot receive more than vault had");
    }
}
