// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/libraries/TimeProviderLibrary.sol";
import "../../src/core/UserPool.sol";
import "../../src/core/HedgerPool.sol";

contract DeployQuantillonPhaseC is Script {
    TimeProvider public timeProvider;
    UserPool public userPool;
    HedgerPool public hedgerPool;

    address public deployerEOA;
    address public usdc;
    address public qeuroToken;
    address public chainlinkOracle;
    address public quantillonVault;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        deployerEOA = vm.addr(pk);

        // Load previous addresses
        timeProvider = TimeProvider(vm.envAddress("TIME_PROVIDER"));
        chainlinkOracle = vm.envAddress("CHAINLINK_ORACLE");
        qeuroToken = vm.envAddress("QEURO_TOKEN");
        quantillonVault = vm.envAddress("QUANTILLON_VAULT");
        usdc = vm.envAddress("USDC");

        console.log("Phase A3: UserPool, HedgerPool");

        vm.startBroadcast(pk);

        _deployUserPoolPhased();
        _deployHedgerPoolPhased();

        vm.stopBroadcast();
        console.log("\nPhase A3 Complete:");
        console.log("UserPool:", address(userPool));
        console.log("HedgerPool:", address(hedgerPool));
    }

    function _deployUserPoolPhased() internal {
        if (address(userPool) == address(0)) {
            UserPool impl = new UserPool(timeProvider);
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            userPool = UserPool(address(proxy));
            userPool.initialize(deployerEOA, qeuroToken, usdc, quantillonVault, chainlinkOracle, address(0), deployerEOA, deployerEOA);
            console.log("UserPool Proxy:", address(userPool));
        }
    }

    function _deployHedgerPoolPhased() internal {
        if (address(hedgerPool) == address(0)) {
            HedgerPool impl = new HedgerPool(timeProvider);
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            hedgerPool = HedgerPool(address(proxy));
            hedgerPool.initialize(deployerEOA, usdc, address(0), deployerEOA, deployerEOA, deployerEOA, quantillonVault);
            hedgerPool.updateOracle(chainlinkOracle);
            console.log("HedgerPool Proxy:", address(hedgerPool));
        }
    }
}

