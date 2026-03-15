// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {stQEUROFactory} from "../src/core/stQEUROFactory.sol";
import {IStQEUROFactory} from "../src/interfaces/IStQEUROFactory.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

contract MockVaultSelfRegister {
    function selfRegister(address factory, uint256 vaultId, string calldata vaultName) external returns (address) {
        return IStQEUROFactory(factory).registerVault(vaultId, vaultName);
    }
}

contract stQEUROFactoryTest is Test {
    address internal admin = address(0xA11CE);
    address internal qeuro = address(0xBEEF);
    address internal yieldShift = address(0xABCD);
    address internal usdc = address(0xCAFE);
    address internal treasury = address(0xFEE1);
    address internal timelock = address(0x1234);
    address internal oracle = address(0x9999);

    stQEUROFactory internal factory;
    stQEUROToken internal tokenImpl;
    MockVaultSelfRegister internal vault;
    MockVaultSelfRegister internal otherVault;

    function setUp() public {
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInit = abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin);
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInit);
        TimeProvider timeProvider = TimeProvider(address(timeProviderProxy));

        tokenImpl = new stQEUROToken(timeProvider);
        stQEUROFactory factoryImpl = new stQEUROFactory();
        bytes memory initData = abi.encodeCall(
            stQEUROFactory.initialize,
            (admin, address(tokenImpl), qeuro, yieldShift, usdc, treasury, timelock, oracle)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImpl), initData);
        factory = stQEUROFactory(address(proxy));

        vault = new MockVaultSelfRegister();
        otherVault = new MockVaultSelfRegister();

        vm.startPrank(admin);
        factory.grantRole(factory.VAULT_FACTORY_ROLE(), address(vault));
        factory.grantRole(factory.VAULT_FACTORY_ROLE(), address(otherVault));
        vm.stopPrank();
    }

    function test_RegisterVault_Success() public {
        address token = vault.selfRegister(address(factory), 1, "CORE");
        assertTrue(token != address(0));

        assertEq(factory.getStQEUROByVaultId(1), token);
        assertEq(factory.getStQEUROByVault(address(vault)), token);
        assertEq(factory.getVaultById(1), address(vault));
        assertEq(factory.getVaultIdByStQEURO(token), 1);
        assertEq(factory.getVaultName(1), "CORE");

        stQEUROToken deployed = stQEUROToken(token);
        assertEq(deployed.symbol(), "stQEUROCORE");
        assertEq(deployed.name(), "Staked Quantillon Euro CORE");
        assertEq(deployed.vaultName(), "CORE");
        assertTrue(deployed.hasRole(deployed.YIELD_MANAGER_ROLE(), yieldShift));
    }

    function test_RegisterVault_DuplicateVaultId_Revert() public {
        vault.selfRegister(address(factory), 1, "CORE");

        vm.expectRevert(CommonErrorLibrary.AlreadyInitialized.selector);
        otherVault.selfRegister(address(factory), 1, "ALPHA");
    }

    function test_RegisterVault_DuplicateVaultAddress_Revert() public {
        vault.selfRegister(address(factory), 1, "CORE");

        vm.expectRevert(CommonErrorLibrary.AlreadyInitialized.selector);
        vault.selfRegister(address(factory), 2, "ALPHA");
    }

    function test_RegisterVault_InvalidVaultName_Revert() public {
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        vault.selfRegister(address(factory), 1, "core");

        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        vault.selfRegister(address(factory), 1, "CORE-1");

        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        vault.selfRegister(address(factory), 1, "ABCDEFGHIJKLMNOPQRSTUVWXYZ");
    }

    function test_RegisterVault_DuplicateVaultName_Revert() public {
        vault.selfRegister(address(factory), 1, "CORE");

        vm.expectRevert(CommonErrorLibrary.AlreadyInitialized.selector);
        otherVault.selfRegister(address(factory), 2, "CORE");
    }

    function test_RegisterVault_Unauthorized_Revert() public {
        MockVaultSelfRegister unauthorizedVault = new MockVaultSelfRegister();
        vm.expectRevert();
        unauthorizedVault.selfRegister(address(factory), 1, "CORE");
    }
}

