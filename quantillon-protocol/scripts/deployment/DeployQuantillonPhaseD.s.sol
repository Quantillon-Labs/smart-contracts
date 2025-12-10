// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/libraries/TimeProviderLibrary.sol";
import "../../src/core/QuantillonVault.sol";
import "../../src/core/UserPool.sol";
import "../../src/core/HedgerPool.sol";
import "../../src/core/FeeCollector.sol";
import "../../src/core/vaults/AaveVault.sol";
import "../../src/core/yieldmanagement/YieldShift.sol";
import "./DeploymentHelpers.sol";

contract DeployQuantillonPhaseD is Script {
    QuantillonVault public quantillonVault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    FeeCollector public feeCollector;
    YieldShift public yieldShift;
    TimeProvider public timeProvider;
    address public stQeuroToken;
    AaveVault public aaveVault;

    address public deployerEOA;
    address public usdc;

    bool public isLocalhost;
    bool public isBaseSepolia;
    bool public isEthereumSepolia;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        deployerEOA = vm.addr(pk);
        (isLocalhost, isBaseSepolia, isEthereumSepolia) = DeploymentHelpers.detectNetwork(block.chainid);

        // Read Phase A, B, C deployed addresses from env
        address tpAddr = vm.envAddress("TIME_PROVIDER");
        address vaultAddr = vm.envAddress("QUANTILLON_VAULT");
        address feeAddr = vm.envAddress("FEE_COLLECTOR");
        stQeuroToken = vm.envAddress("STQEURO_TOKEN");
        address upAddr = vm.envAddress("USER_POOL");
        address hpAddr = vm.envAddress("HEDGER_POOL");
        usdc = DeploymentHelpers.selectUSDCAddress(vm.envOr("WITH_MOCKS", false), block.chainid);
        if (usdc == address(0)) {
            usdc = vm.envAddress("USDC");
        }
        console.log("USDC:", usdc);
        aaveVault = AaveVault(vm.envAddress("AAVE_VAULT"));
        console.log("AaveVault:", address(aaveVault));

        timeProvider = TimeProvider(tpAddr);
        quantillonVault = QuantillonVault(vaultAddr);
        userPool = UserPool(upAddr);
        hedgerPool = HedgerPool(hpAddr);
        feeCollector = FeeCollector(feeAddr);

        console.log("Phase B: YieldShift + Wiring");
        console.log("Debug: QuantillonVault address from env:", address(quantillonVault));
        console.log("Debug: HedgerPool address from env:", address(hedgerPool));

        vm.startBroadcast(pk);

        // Deploy full YieldShift (now in separate script with own gas budget)
        if (address(yieldShift) == address(0)) {
            YieldShift impl = new YieldShift(timeProvider);
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            yieldShift = YieldShift(address(proxy));
            console.log("YieldShift Proxy:", address(yieldShift));
            yieldShift.initialize(deployerEOA, usdc, address(0), address(0), address(0), address(0), deployerEOA, deployerEOA);
            yieldShift.updateUserPool(address(userPool));
            yieldShift.updateHedgerPool(address(hedgerPool));
            yieldShift.updateAaveVault(address(aaveVault));
            yieldShift.updateStQEURO(stQeuroToken);
            yieldShift.bootstrapDefaults();
            hedgerPool.updateAddress(3, address(yieldShift));
        }

        // Wire vault/pools
        quantillonVault.updateHedgerPool(address(hedgerPool));
        quantillonVault.updateUserPool(address(userPool));
        feeCollector.authorizeFeeSource(address(quantillonVault));
        hedgerPool.setHedgerWhitelist(deployerEOA, true);

        // =============================================================================
        // AAVE INTEGRATION WIRING
        // Connect QuantillonVault to AaveVault for automatic USDC deployment
        // =============================================================================
        if (address(aaveVault) != address(0)) {
            // Set AaveVault address on QuantillonVault for auto-deployment on mint
            quantillonVault.updateAaveVault(address(aaveVault));
            console.log("QuantillonVault.aaveVault set to:", address(aaveVault));
            
            // Grant VAULT_MANAGER_ROLE on AaveVault to QuantillonVault
            // This allows QuantillonVault to call aaveVault.deployToAave() and withdrawFromAave()
            bytes32 vaultManagerRole = aaveVault.VAULT_MANAGER_ROLE();
            if (!aaveVault.hasRole(vaultManagerRole, address(quantillonVault))) {
                aaveVault.grantRole(vaultManagerRole, address(quantillonVault));
                console.log("Granted VAULT_MANAGER_ROLE on AaveVault to QuantillonVault");
            }
        } else {
            console.log("WARNING: AaveVault not set, skipping Aave integration wiring");
        }

        vm.stopBroadcast();
        console.log("\nPhase B Complete. YieldShift:", address(yieldShift));
    }

}

