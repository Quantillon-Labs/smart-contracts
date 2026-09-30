// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UserPool} from "../../src/core/UserPool.sol";
import {stQEUROFactory} from "../../src/core/stQEUROFactory.sol";
import {ExecutionPricing} from "../../src/oracle/ExecutionPricing.sol";
import {TimeProvider} from "../../src/libraries/TimeProviderLibrary.sol";
import {CommonErrorLibrary} from "../../src/libraries/CommonErrorLibrary.sol";

interface IProductionVaultView {
    function paused() external view returns (bool);
    function oracle() external view returns (address);
    function mintFee() external view returns (uint256);
    function redemptionFee() external view returns (uint256);
    function usdc() external view returns (address);
}

contract RemediationProductionForkTest is Test {
    uint256 private constant FORK_BLOCK = 51_988_012;
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address private constant VAULT = 0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07;
    address private constant USER_POOL = 0x712bCc77e7aa53C79870A40d044D440Ad2901bF2;
    address private constant FACTORY = 0x0382B0b9FB6Ff737209C3B31D727BB9d2E2bcb53;
    address private constant PRICING = 0xFA894CD2e0C8030c95925FfF3b8206F397e0D897;
    address private constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address private constant SAFE = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd;
    address private constant TIMELOCK = 0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true, "set BASE_FORK_RPC_URL to run production-fork validation");
            return;
        }
        vm.createSelectFork(rpc, FORK_BLOCK);
        assertEq(block.chainid, 8453);
        assertTrue(VAULT.code.length != 0 && USER_POOL.code.length != 0 && FACTORY.code.length != 0);
    }

    function test_ReplacementPricingBoundsDegradedAdmission() public {
        ExecutionPricing livePricing = ExecutionPricing(PRICING);
        ExecutionPricing replacement = new ExecutionPricing(
            [
                VAULT,
                livePricing.venueOracle(),
                address(this),
                address(this),
                address(this),
                livePricing.reserveRecipient()
            ],
            [
                livePricing.maxAge(),
                livePricing.maxImpactBps(),
                livePricing.bufferBps(),
                livePricing.maxOutstanding()
            ]
        );
        replacement.acknowledge(0, 0, livePricing.maxOutstanding(), block.timestamp);

        uint256 limit = livePricing.maxOutstanding();
        ExecutionPricing.Quote memory quote = replacement.previewRedeem(limit);
        assertEq(quote.capacityQeuro, limit);
        vm.prank(VAULT);
        replacement.consumeRedeem(limit, quote.referenceRate);

        vm.expectRevert(CommonErrorLibrary.InsufficientBalance.selector);
        replacement.previewRedeem(1);
        assertEq(replacement.version(), "1.3.3");
    }

    function test_FactoryUpgradeBackfillsExistingNameBeforeRegistration() public {
        stQEUROFactory factory = stQEUROFactory(FACTORY);
        address existingToken = factory.getStQEUROByVaultId(2);
        assertTrue(existingToken != address(0));
        assertEq(factory.getVaultName(2), "MORPHO1");
        uint256[] memory existingVaultIds = factory.getVaultIdsByVault(VAULT);
        assertEq(existingVaultIds.length, 1);
        assertEq(existingVaultIds[0], 2);
        assertTrue(factory.hasRole(factory.VAULT_FACTORY_ROLE(), VAULT));

        stQEUROFactory implementation = new stQEUROFactory();
        vm.store(FACTORY, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(implementation)))));
        assertEq(factory.getStQEUROByVaultId(2), existingToken);
        assertFalse(factory.vaultNameHashesMigrated());

        vm.prank(VAULT);
        vm.expectRevert(CommonErrorLibrary.NotInitialized.selector);
        factory.registerVault(10_002, "MORPHO2");

        assertTrue(factory.hasRole(factory.GOVERNANCE_ROLE(), SAFE));
        uint256[] memory vaultIds = new uint256[](1);
        vaultIds[0] = 2;
        vm.prank(SAFE);
        factory.initializeVaultNameHashesV2(vaultIds);

        vm.prank(VAULT);
        vm.expectRevert(CommonErrorLibrary.AlreadyInitialized.selector);
        factory.registerVault(10_001, "MORPHO1");
        vm.prank(VAULT);
        assertTrue(factory.registerVault(10_002, "MORPHO2") != address(0));
        assertEq(factory.version(), "1.0.5");
    }

    function test_UserPoolUpgradeInitializesRecoveryReserve() public {
        UserPool pool = UserPool(USER_POOL);
        uint256 stakesBefore = pool.totalStakes();
        address treasury = pool.treasury();
        TimeProvider timeProvider = pool.TIME_PROVIDER();

        UserPool implementation = new UserPool(timeProvider);
        vm.store(USER_POOL, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(implementation)))));
        assertEq(pool.totalStakes(), stakesBefore);
        assertFalse(pool.pendingUsdcLiabilitiesInitialized());

        vm.prank(TIMELOCK);
        vm.expectRevert(CommonErrorLibrary.NotInitialized.selector);
        pool.recoverToken(USDC, 1);

        assertTrue(pool.hasRole(pool.GOVERNANCE_ROLE(), SAFE));
        vm.prank(SAFE);
        pool.initializePendingUsdcLiabilitiesV2();

        deal(USDC, USER_POOL, 10e6);
        uint256 treasuryBefore = IERC20(USDC).balanceOf(treasury);
        vm.prank(TIMELOCK);
        pool.recoverToken(USDC, 10e6);
        assertEq(IERC20(USDC).balanceOf(treasury), treasuryBefore + 10e6);
        assertEq(pool.version(), "1.0.7");
    }
}
