// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Vm} from "forge-std/Vm.sol";

import {AaveIntegrationTest} from "./AaveIntegration.t.sol";
import {stQEUROFactory} from "../src/core/stQEUROFactory.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";

/**
 * @title StQEUROYieldDistributionTest
 * @notice Tests the §2a yield-distribution model implemented by
 *         `QuantillonVault.harvestAndDistributeVaultYield`: the hedger funding share is carved out
 *         first (absolute, time-prorated funding rate), the residual is credited to stQEURO holders
 *         pro-rata to staked/circulating QEURO (rising share price), and the remainder goes to treasury.
 *         Funding is configured at 0.5% (the agreed test value; commercial launch uses 0).
 */
contract StQEUROYieldDistributionTest is AaveIntegrationTest {
    stQEUROFactory internal factory;
    stQEUROToken internal stToken;

    uint256 internal constant VAULT_ID = 1; // the Aave-mock staking vault wired in AaveIntegrationTest.setUp
    uint256 internal constant FUNDING_RATE_BPS = 50; // 0.5% annualized
    address internal hedgerSink = address(0xBEEF);

    /// @notice Deploys an stQEURO series for VAULT_ID and configures the distribution parameters.
    function _setUpStaking() internal {
        vm.startPrank(admin);
        stQEUROToken tokenImplementation = new stQEUROToken(timeProvider);
        stQEUROFactory factoryImplementation = new stQEUROFactory();
        factory = stQEUROFactory(
            address(
                new ERC1967Proxy(
                    address(factoryImplementation),
                    abi.encodeWithSelector(
                        stQEUROFactory.initialize.selector,
                        admin,
                        address(tokenImplementation),
                        address(qeuro),
                        address(0xCAFE),
                        address(usdc),
                        treasury,
                        treasury,
                        address(oracle)
                    )
                )
            )
        );
        factory.grantRole(factory.VAULT_FACTORY_ROLE(), address(vault));
        stToken = stQEUROToken(vault.selfRegisterStQEURO(address(factory), VAULT_ID, "AAVE"));

        vault.grantRole(vault.YIELD_DISTRIBUTOR_ROLE(), admin);
        vault.setFundingRateAnnualBps(FUNDING_RATE_BPS);
        vault.setHedgerYieldRecipient(hedgerSink);

        usdc.mint(user, 200_000e6); // extra USDC for mint + stake below
        vm.stopPrank();
    }

    /// @notice Builds an unstaked QEURO balance + a staked stQEURO position, both deploying principal.
    function _seedPositions(uint256 unstakedUsdc, uint256 stakeUsdc) internal returns (uint256 stShares) {
        vm.startPrank(user);
        usdc.approve(address(vault), unstakedUsdc + stakeUsdc);
        vault.mintQEURO(unstakedUsdc, 0); // unstaked circulating QEURO + principal to VAULT_ID
        (, stShares) = vault.mintAndStakeQEURO(stakeUsdc, 0, VAULT_ID, 1); // staked QEURO + principal
        vm.stopPrank();
        assertGt(stShares, 0, "user holds a staked position");
    }

    /// @notice Primes the funding clock so the next distribution accrues a non-zero hedger share.
    function _prime() internal {
        vm.prank(admin);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
    }

    /// @notice Triggers harvest+distribute (as admin) and returns the split decoded from the
    ///         VaultYieldDistributed event (the function no longer returns the values).
    function _distribute()
        internal
        returns (uint256 realized, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare)
    {
        vm.recordLogs();
        vm.prank(admin);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("VaultYieldDistributed(uint256,uint256,uint256,uint256,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == sig) {
                return abi.decode(logs[i].data, (uint256, uint256, uint256, uint256));
            }
        }
        revert("VaultYieldDistributed not emitted");
    }

    // -------------------------------------------------------------------------

    /// @notice At 0.5% funding the hedger is paid first (exact formula), stakers' share price rises,
    ///         and the unstaked remainder goes to treasury; all realized yield is fully distributed.
    function test_harvestAndDistribute_paysHedgerFirstAndRaisesSharePrice() public {
        _setUpStaking();
        uint256 stShares = _seedPositions(20_000e6, 10_000e6);
        _prime();

        (, , uint256 notional, ) = vault.getVaultExposure(VAULT_ID);
        assertGt(notional, 0, "principal deployed to adapter");

        uint256 yieldUsdc = 2_000e6;
        vm.warp(block.timestamp + 365 days);
        mockAaveVault.setAccruedYield(yieldUsdc);

        uint256 shareValueBefore = stToken.convertToAssets(1e18);
        uint256 redeemBefore = stToken.previewRedeem(stShares);
        uint256 hedgerBefore = usdc.balanceOf(hedgerSink);
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 circulating = qeuro.totalSupply();
        uint256 staked = stToken.totalAssets();

        (uint256 realized, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare) = _distribute();

        // Hedger first, exactly 0.5% annualized of the deployed notional over one year.
        uint256 expectedHedger = (notional * FUNDING_RATE_BPS) / 10000;
        assertEq(realized, yieldUsdc, "realized == accrued yield harvested");
        assertEq(hedgerShare, expectedHedger, "hedger share == 0.5% annualized of notional");
        assertLt(hedgerShare, realized, "funding stays below yield (no user ponction)");
        assertEq(usdc.balanceOf(hedgerSink) - hedgerBefore, hedgerShare, "hedger recipient funded");

        // Residual split staked/circulating; remainder to treasury.
        uint256 residual = realized - hedgerShare;
        uint256 expectedUser = (residual * staked) / circulating;
        assertEq(userShare, expectedUser, "user share == residual * staked / circulating");
        assertGt(treasuryShare, 0, "treasury receives the unstaked remainder");
        assertEq(treasuryShare, residual - expectedUser, "treasury == residual - userShare");
        assertEq(usdc.balanceOf(treasury) - treasuryBefore, treasuryShare, "treasury funded");

        // Conservation: every realized USDC is routed.
        assertEq(hedgerShare + userShare + treasuryShare, realized, "all realized yield distributed");

        // Stakers actually accrue: share price and redeemable value rise.
        assertGt(stToken.convertToAssets(1e18), shareValueBefore, "share price rose");
        assertGt(stToken.previewRedeem(stShares), redeemBefore, "staker redeemable rose");
    }

    /// @notice With funding at 0 (commercial launch), the hedger gets nothing and the full yield is
    ///         split between stakers (share price) and treasury.
    function test_harvestAndDistribute_zeroFunding_noHedgerCut() public {
        _setUpStaking();
        vm.prank(admin);
        vault.setFundingRateAnnualBps(0);

        _seedPositions(20_000e6, 10_000e6);
        _prime();

        uint256 hedgerBefore = usdc.balanceOf(hedgerSink);
        vm.warp(block.timestamp + 365 days);
        mockAaveVault.setAccruedYield(1_000e6);

        (uint256 realized, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare) = _distribute();

        assertEq(hedgerShare, 0, "no funding carve-out at 0 bps");
        assertEq(usdc.balanceOf(hedgerSink), hedgerBefore, "hedger recipient untouched");
        assertEq(userShare + treasuryShare, realized, "entire yield split between users and treasury");
        assertGt(userShare, 0, "stakers accrue");
    }

    /// @notice Only a YIELD_DISTRIBUTOR_ROLE holder can trigger harvest+distribute.
    function test_harvestAndDistribute_onlyYieldDistributor() public {
        _setUpStaking();
        vm.prank(user);
        vm.expectRevert();
        vault.harvestAndDistributeVaultYield(VAULT_ID);
    }

    /// @notice When the time-prorated funding accrual exceeds the realized yield, the hedger share is
    ///         capped at the realized yield and stakers/treasury receive nothing (no principal ponction).
    function test_harvestAndDistribute_fundingCapBinds() public {
        _setUpStaking();
        _seedPositions(20_000e6, 10_000e6);
        _prime();

        (, , uint256 notional, ) = vault.getVaultExposure(VAULT_ID);
        uint256 accruedFunding = (notional * FUNDING_RATE_BPS) / 10000; // 1y at 0.5%
        uint256 yieldUsdc = accruedFunding / 3; // realized yield well below the funding accrual
        assertGt(yieldUsdc, 0, "fixture sanity: nonzero yield");

        vm.warp(block.timestamp + 365 days);
        mockAaveVault.setAccruedYield(yieldUsdc);

        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 shareValueBefore = stToken.convertToAssets(1e18);

        (uint256 realized, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare) = _distribute();

        assertEq(realized, yieldUsdc, "realized == accrued yield");
        assertEq(hedgerShare, realized, "hedger share capped at realized yield");
        assertEq(userShare, 0, "no staker residual when the cap binds");
        assertEq(treasuryShare, 0, "no treasury remainder when the cap binds");
        assertEq(usdc.balanceOf(treasury), treasuryBefore, "treasury untouched");
        assertEq(stToken.convertToAssets(1e18), shareValueBefore, "share price unchanged");
    }

    /// @notice With zero realized yield the distribution is a harmless no-op: an all-zero split,
    ///         no transfers, no share-price movement.
    function test_harvestAndDistribute_zeroYield_noOp() public {
        _setUpStaking();
        _seedPositions(20_000e6, 10_000e6);
        _prime();

        vm.warp(block.timestamp + 30 days); // funding clock runs, but there is nothing to carve from

        uint256 hedgerBefore = usdc.balanceOf(hedgerSink);
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 shareValueBefore = stToken.convertToAssets(1e18);

        (uint256 realized, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare) = _distribute();

        assertEq(realized, 0, "nothing realized");
        assertEq(hedgerShare + userShare + treasuryShare, 0, "all-zero split");
        assertEq(usdc.balanceOf(hedgerSink), hedgerBefore, "hedger untouched");
        assertEq(usdc.balanceOf(treasury), treasuryBefore, "treasury untouched");
        assertEq(stToken.convertToAssets(1e18), shareValueBefore, "share price unchanged");
    }

    /// @notice With a per-series yieldFee, the treasury receives treasuryShare + fee while the event
    ///         reports the PRE-fee userShare; stakers accrue only the net (userShare - fee).
    function test_harvestAndDistribute_yieldFee_treasuryGetsShareAndFee() public {
        _setUpStaking();
        uint256 feeBps = 1000; // 10%
        vm.prank(admin);
        stToken.updateYieldParameters(feeBps);

        _seedPositions(20_000e6, 10_000e6);
        _prime();

        vm.warp(block.timestamp + 365 days);
        mockAaveVault.setAccruedYield(2_000e6);

        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 stakedBefore = stToken.totalAssets();

        (uint256 realized, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare) = _distribute();
        uint256 feeUsdc = (userShare * feeBps) / 10000;
        assertGt(feeUsdc, 0, "fixture sanity: nonzero fee");

        // Event semantics: userShare is PRE-fee; the fee is carved out inside the credit path.
        assertEq(hedgerShare + userShare + treasuryShare, realized, "event split conserves realized yield");
        assertEq(
            usdc.balanceOf(treasury) - treasuryBefore,
            treasuryShare + feeUsdc,
            "treasury receives its share plus the yield fee"
        );
        // Stakers accrue the net credit (userShare - fee), valued in QEURO via the oracle price.
        assertGt(stToken.totalAssets(), stakedBefore, "stakers accrue net of fee");
    }
}
