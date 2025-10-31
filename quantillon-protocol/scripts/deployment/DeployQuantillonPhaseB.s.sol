// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/libraries/TimeProviderLibrary.sol";
import "../../src/core/QTIToken.sol";
import "../../src/core/stQEUROToken.sol";
import "../../src/core/vaults/AaveVault.sol";
import "./MockAaveContracts.sol";

contract DeployQuantillonPhaseB is Script {
    TimeProvider public timeProvider;
    QTIToken public qtiToken;
    stQEUROToken public stQeuroToken;
    AaveVault public aaveVault;

    address public deployerEOA;
    address public usdc;
    address public qeuroToken;
    address public chainlinkOracle;
    address public aaveProvider;
    address public aaveRewardsController;
    bool public isLocalhost;
    bool public isBaseSepolia;
    bool public isEthereumSepolia;

    address constant BASE_SEPOLIA_AAVE_PROVIDER = 0x012Bef543e50E6F4b5C79e6c5Adf0F31f659860c;
    address constant BASE_SEPOLIA_AAVE_REWARDS = 0x7794835f9E2eD8d4B8d4C4c0E4B8c4C8c0e4b8C4;
    address constant BASE_SEPOLIA_USDC_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    
    // Ethereum Sepolia addresses
    address constant ETHEREUM_SEPOLIA_AAVE_PROVIDER = 0x23688b717AA97e7B95b6e2B636f8216B9Fe72003;
    address constant ETHEREUM_SEPOLIA_AAVE_REWARDS = 0x034270A10E81d657D196864EBD57bf3ABBdFefe0;
    address constant ETHEREUM_SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        deployerEOA = vm.addr(pk);
        _detectNetwork();

        // Load Phase A1 addresses
        timeProvider = TimeProvider(vm.envAddress("TIME_PROVIDER"));
        chainlinkOracle = vm.envAddress("CHAINLINK_ORACLE");
        qeuroToken = vm.envAddress("QEURO_TOKEN");
        
        // Select USDC address using same logic as Phase A
        _selectUSDCAddress();

        console.log("Phase A2: QTI, AaveVault, stQEURO");

        vm.startBroadcast(pk);
        _selectAaveAddresses();

        _deployQTIPhased();
        _deployAaveVaultPhased();
        _deployStQEUROPhased();

        vm.stopBroadcast();
        console.log("\nPhase A2 Complete:");
        console.log("QTIToken:", address(qtiToken));
        console.log("AaveVault:", address(aaveVault));
        console.log("stQEUROToken:", address(stQeuroToken));
    }

    function _detectNetwork() internal {
        uint256 cid = block.chainid;
        isLocalhost = (cid == 31337);
        isBaseSepolia = (cid == 84532);
        isEthereumSepolia = (cid == 11155111);
    }

    function _selectUSDCAddress() internal {
        bool withMocks = vm.envOr("WITH_MOCKS", false);
        // Same logic as Phase A: use constants when not mocks, env when mocks (injected by deploy script)
        if (isLocalhost) {
            usdc = vm.envAddress("USDC");
        } else if (isBaseSepolia) {
            usdc = withMocks ? vm.envAddress("USDC") : BASE_SEPOLIA_USDC_TOKEN;
        } else if (isEthereumSepolia) {
            usdc = withMocks ? vm.envAddress("USDC") : ETHEREUM_SEPOLIA_USDC_TOKEN;
        } else {
            usdc = vm.envAddress("USDC");
        }
        console.log("USDC:", usdc);
    }

    function _selectAaveAddresses() internal {
        bool withMocks = vm.envOr("WITH_MOCKS", false);
        if (isLocalhost || withMocks) {
            MockAavePool mockPool = new MockAavePool(usdc, usdc);
            MockPoolAddressesProvider mockProvider = new MockPoolAddressesProvider(address(mockPool));
            MockRewardsController mockRewards = new MockRewardsController();
            aaveProvider = address(mockProvider);
            aaveRewardsController = address(mockRewards);
        } else if (isBaseSepolia) {
            aaveProvider = BASE_SEPOLIA_AAVE_PROVIDER;
            aaveRewardsController = BASE_SEPOLIA_AAVE_REWARDS;
            // Fallback to mocks if these addresses are not contracts on Base Sepolia
            address provider = aaveProvider;
            address rewards = aaveRewardsController;
            uint256 sizeProvider;
            uint256 sizeRewards;
            assembly {
                sizeProvider := extcodesize(provider)
                sizeRewards := extcodesize(rewards)
            }
            if (sizeProvider == 0 || sizeRewards == 0) {
                console.log("Base Sepolia Aave addresses not contracts, falling back to mocks");
                MockAavePool mockPool = new MockAavePool(usdc, usdc);
                MockPoolAddressesProvider mockProvider = new MockPoolAddressesProvider(address(mockPool));
                MockRewardsController mockRewards = new MockRewardsController();
                aaveProvider = address(mockProvider);
                aaveRewardsController = address(mockRewards);
            }
        } else if (isEthereumSepolia) {
            aaveProvider = ETHEREUM_SEPOLIA_AAVE_PROVIDER;
            aaveRewardsController = ETHEREUM_SEPOLIA_AAVE_REWARDS;
            // Fallback to mocks if these addresses are not contracts on Ethereum Sepolia
            address provider = aaveProvider;
            address rewards = aaveRewardsController;
            uint256 sizeProvider;
            uint256 sizeRewards;
            assembly {
                sizeProvider := extcodesize(provider)
                sizeRewards := extcodesize(rewards)
            }
            if (sizeProvider == 0 || sizeRewards == 0) {
                console.log("Ethereum Sepolia Aave addresses not contracts, falling back to mocks");
                MockAavePool mockPool = new MockAavePool(usdc, usdc);
                MockPoolAddressesProvider mockProvider = new MockPoolAddressesProvider(address(mockPool));
                MockRewardsController mockRewards = new MockRewardsController();
                aaveProvider = address(mockProvider);
                aaveRewardsController = address(mockRewards);
            }
        }
    }

    function _deployQTIPhased() internal {
        if (address(qtiToken) == address(0)) {
            QTIToken impl = new QTIToken(timeProvider);
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            qtiToken = QTIToken(address(proxy));
            qtiToken.initialize(deployerEOA, deployerEOA, deployerEOA);
            console.log("QTI Proxy:", address(qtiToken));
        }
    }

    function _deployAaveVaultPhased() internal {
        if (address(aaveVault) == address(0)) {
            AaveVault impl = new AaveVault();
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            aaveVault = AaveVault(address(proxy));
            aaveVault.initialize(deployerEOA, usdc, aaveProvider, aaveRewardsController, deployerEOA, deployerEOA, deployerEOA);
            console.log("AaveVault Proxy:", address(aaveVault));
        }
    }

    function _deployStQEUROPhased() internal {
        if (address(stQeuroToken) == address(0)) {
            stQEUROToken impl = new stQEUROToken(timeProvider);
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            stQeuroToken = stQEUROToken(address(proxy));
            stQeuroToken.initialize(deployerEOA, qeuroToken, deployerEOA, usdc, deployerEOA, deployerEOA);
            console.log("stQEURO Proxy:", address(stQeuroToken));
        }
    }

}

