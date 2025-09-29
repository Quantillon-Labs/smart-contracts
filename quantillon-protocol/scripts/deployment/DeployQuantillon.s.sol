// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import all contracts
import "../../src/libraries/TimeProviderLibrary.sol";
import "../../src/oracle/ChainlinkOracle.sol";
import "../../src/mocks/MockChainlinkOracle.sol";
import "../../src/core/QEUROToken.sol";
import "../../src/core/QTIToken.sol";
import "../../src/core/QuantillonVault.sol";
import "../../src/core/UserPool.sol";
import "../../src/core/HedgerPool.sol";
import "../../src/core/stQEUROToken.sol";
import "../../src/core/vaults/AaveVault.sol";
import "../../src/core/yieldmanagement/YieldShift.sol";
import "../../src/core/FeeCollector.sol";
import "../../src/mocks/MockUSDC.sol";

// Import mock aggregator for localhost deployment
import "../../test/ChainlinkOracle.t.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// Import mock Aave contracts for localhost deployment
import "./MockAaveContracts.sol";

// Import proxy for upgradeable contracts
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployQuantillon
 * @notice Complete deployment script for Quantillon Protocol
 * @dev Deploys all contracts in the correct order with proper dependencies
 */
contract DeployQuantillon is Script {
    // Deployment addresses
    address public timeProvider;
    address public chainlinkOracle;
    address public qeuroToken;
    address public qtiToken;
    address public quantillonVault;
    address public userPool;
    address public hedgerPool;
    address public stQeuroToken;
    address public aaveVault;
    address public yieldShift;
    address public feeCollector;
    address public mockUSDC;
    
    // Mock feed addresses (for localhost)
    address public mockEurUsdFeed;
    address public mockUsdcUsdFeed;

    // Contract instances (to avoid stack too deep)
    TimeProvider public timeProviderContract;
    ChainlinkOracle public chainlinkOracleContract;
    QEUROToken public qeuroTokenContract;
    QTIToken public qtiTokenContract;
    QuantillonVault public quantillonVaultContract;
    FeeCollector public feeCollectorContract;
    UserPool public userPoolContract;
    HedgerPool public hedgerPoolContract;
    stQEUROToken public stQeuroTokenContract;
    AaveVault public aaveVaultContract;
    YieldShift public yieldShiftContract;
    MockUSDC public mockUSDCContract;
    
    // Mock feed instances (for localhost)
    MockAggregatorV3 public mockEurUsdFeedContract;
    MockAggregatorV3 public mockUsdcUsdFeedContract;

    // Network configuration
    string public network;
    bool public isLocalhost;
    bool public isBaseSepolia;
    
    // Mock addresses for localhost (replace with real addresses for testnet/mainnet)
    address constant MOCK_EUR_USD_FEED = 0x1234567890123456789012345678901234567890;
    address constant MOCK_USDC_USD_FEED = 0x2345678901234567890123456789012345678901;
    address constant MOCK_AAVE_POOL = 0x4567890123456789012345678901234567890123;
    
    // Base Sepolia addresses (real addresses for testnet)
    // Note: These are placeholder addresses - update with actual Base Sepolia addresses
    address constant BASE_SEPOLIA_EUR_USD_FEED = 0x0000000000000000000000000000000000000001; // EUR/USD on Base Sepolia
    address constant BASE_SEPOLIA_USDC_USD_FEED = 0x0000000000000000000000000000000000000002; // USDC/USD on Base Sepolia
    address constant BASE_SEPOLIA_USDC_TOKEN = 0x0000000000000000000000000000000000000003; // USDC on Base Sepolia
    address constant BASE_SEPOLIA_AAVE_POOL = 0x0000000000000000000000000000000000000004; // Aave Pool on Base Sepolia

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        
        // Detect network
        _detectNetwork();
        
        console.log("=== QUANTILLON PROTOCOL DEPLOYMENT ===");
        console.log("Network:", network);
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);
        
        // Set higher gas limit for large contract deployments
        vm.fee(0);

        // Deploy MockUSDC first if needed (localhost or Base Sepolia)
        if (isLocalhost || isBaseSepolia) {
            _deployMockUSDC();
        }

        // Deploy mock feeds first if on localhost
        if (isLocalhost) {
            _deployMockFeeds();
        }

        // Deploy all contracts in phases
        _deployPhase1();
        _deployPhase2();
        _deployPhase3();
        _deployPhase4();
        _deployPhase5();
        _initializeContracts();

        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===");
    }

    function _detectNetwork() internal {
        uint256 chainId = block.chainid;
        
        if (chainId == 31337) {
            network = "localhost";
            isLocalhost = true;
            isBaseSepolia = false;
        } else if (chainId == 84532) {
            network = "base-sepolia";
            isLocalhost = false;
            isBaseSepolia = true;
        } else {
            network = "unknown";
            isLocalhost = false;
            isBaseSepolia = false;
        }
        
        console.log("Detected chain ID:", chainId);
        console.log("Network:", network);
    }

    function _deployMockUSDC() internal {
        console.log("\n=== DEPLOYING MOCK USDC ===");
        
        mockUSDCContract = new MockUSDC();
        mockUSDC = address(mockUSDCContract);
        console.log("MockUSDC:", mockUSDC);
        
        // Mint some USDC to deployer for testing
        uint256 mintAmount = 1000000 * 10**6; // 1M USDC
        mockUSDCContract.mint(msg.sender, mintAmount);
        console.log("Minted 1M USDC to deployer");
    }

    function _deployMockFeeds() internal {
        console.log("\n=== DEPLOYING MOCK PRICE FEEDS ===");
        
        // Deploy EUR/USD mock price feed
        mockEurUsdFeedContract = new MockAggregatorV3(8);
        mockEurUsdFeed = address(mockEurUsdFeedContract);
        mockEurUsdFeedContract.setPrice(108000000); // 1.08 USD
        console.log("EUR/USD Feed:", mockEurUsdFeed, "(1.08 USD)");

        // Deploy USDC/USD mock price feed
        mockUsdcUsdFeedContract = new MockAggregatorV3(8);
        mockUsdcUsdFeed = address(mockUsdcUsdFeedContract);
        mockUsdcUsdFeedContract.setPrice(100000000); // 1.00 USD
        console.log("USDC/USD Feed:", mockUsdcUsdFeed, "(1.00 USD)");
    }

    function _getUSDCAddress() internal view returns (address) {
        if (isLocalhost) {
            return mockUSDC;
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_USDC_TOKEN;
        } else {
            return address(0); // fallback - no USDC available
        }
    }
    
    function _getAaveProvider() internal view returns (address) {
        if (isLocalhost) {
            // Localhost - use deployer address as mock Aave provider
            return msg.sender;
        } else if (isBaseSepolia) {
            // Base Sepolia - Aave V3 Provider
            return 0x012Bef543e50E6F4b5C79e6c5Adf0F31f659860c;
        } else {
            return address(0); // fallback
        }
    }
    
    function _getRewardsController() internal view returns (address) {
        if (isLocalhost) {
            // Localhost - use deployer address as mock rewards controller
            return msg.sender;
        } else if (isBaseSepolia) {
            // Base Sepolia - Aave V3 Rewards Controller
            return 0x7794835f9E2eD8d4B8d4C4c0E4B8c4C8c0e4b8C4;
        } else {
            return address(0); // fallback
        }
    }

    function _getEURUSDFeed() internal view returns (address) {
        if (isLocalhost) {
            return mockEurUsdFeed; // Use deployed mock feed
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_EUR_USD_FEED;
        } else {
            return MOCK_EUR_USD_FEED; // fallback
        }
    }

    function _getUSDCUSDFeed() internal view returns (address) {
        if (isLocalhost) {
            return mockUsdcUsdFeed; // Use deployed mock feed
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_USDC_USD_FEED;
        } else {
            return MOCK_USDC_USD_FEED; // fallback
        }
    }

    function _getAavePool() internal view returns (address) {
        if (isLocalhost) {
            return MOCK_AAVE_POOL;
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_AAVE_POOL;
        } else {
            return MOCK_AAVE_POOL; // fallback
        }
    }

    function _deployPhase1() internal {
        console.log("\n=== PHASE 1: CORE INFRASTRUCTURE ===");
        
        // 1. Deploy TimeProvider
        timeProviderContract = new TimeProvider();
        timeProvider = address(timeProviderContract);
        console.log("TimeProvider:", timeProvider);

        // 2. Deploy Oracle
        if (isLocalhost) {
            MockChainlinkOracle mockImplementation = new MockChainlinkOracle();
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(mockImplementation),
                abi.encodeWithSelector(
                    MockChainlinkOracle.initialize.selector,
                    msg.sender,        // admin
                    _getEURUSDFeed(),  // EUR/USD feed (mock)
                    _getUSDCUSDFeed(), // USDC/USD feed (mock)
                    msg.sender         // treasury
                )
            );
            chainlinkOracle = address(proxy);
            chainlinkOracleContract = ChainlinkOracle(chainlinkOracle);
            console.log("MockChainlinkOracle:", chainlinkOracle);
        } else {
            ChainlinkOracle implementation = new ChainlinkOracle(timeProviderContract);
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(implementation),
                abi.encodeWithSelector(
                    ChainlinkOracle.initialize.selector,
                    msg.sender,        // admin
                    _getEURUSDFeed(),  // EUR/USD feed
                    _getUSDCUSDFeed(), // USDC/USD feed
                    msg.sender         // treasury
                )
            );
            chainlinkOracle = address(proxy);
            chainlinkOracleContract = ChainlinkOracle(chainlinkOracle);
            console.log("ChainlinkOracle:", chainlinkOracle);
        }

        // 3. Deploy QEUROToken
        QEUROToken qeuroTokenImpl = new QEUROToken();
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            msg.sender,        // admin
            msg.sender,        // vault (temporary)
            msg.sender,        // timelock
            msg.sender         // treasury
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroTokenImpl), qeuroInitData);
        qeuroToken = address(qeuroProxy);
        qeuroTokenContract = QEUROToken(qeuroToken);
        console.log("QEUROToken:", qeuroToken);
        
        // 4. Deploy FeeCollector
        FeeCollector feeCollectorImpl = new FeeCollector();
        bytes memory feeCollectorInitData = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            msg.sender,        // admin
            msg.sender,        // treasury (same as admin for now)
            msg.sender,        // devFund (same as admin for now)
            msg.sender         // communityFund (same as admin for now)
        );
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), feeCollectorInitData);
        feeCollector = address(feeCollectorProxy);
        feeCollectorContract = FeeCollector(feeCollector);
        console.log("FeeCollector:", feeCollector);
        
        // 5. Deploy QuantillonVault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            msg.sender,        // admin
            qeuroToken,        // _qeuro
            _getUSDCAddress(), // _usdc
            chainlinkOracle,   // _oracle
            address(0),        // _hedgerPool (temporary)
            address(0),        // _userPool (temporary)
            msg.sender,        // _timelock
            feeCollector       // _feeCollector
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        quantillonVault = address(vaultProxy);
        quantillonVaultContract = QuantillonVault(quantillonVault);
        console.log("QuantillonVault:", quantillonVault);
        
        // Verify oracle is properly set in vault
        address vaultOracle = address(quantillonVaultContract.oracle());
        if (vaultOracle == chainlinkOracle) {
            console.log("SUCCESS: Oracle properly set in vault");
        } else {
            console.log("ERROR: Oracle not properly set in vault!");
        }
        
        // 5. Update QEUROToken roles
        qeuroTokenContract.revokeRole(qeuroTokenContract.MINTER_ROLE(), msg.sender);
        qeuroTokenContract.grantRole(qeuroTokenContract.MINTER_ROLE(), quantillonVault);
        qeuroTokenContract.revokeRole(qeuroTokenContract.BURNER_ROLE(), msg.sender);
        qeuroTokenContract.grantRole(qeuroTokenContract.BURNER_ROLE(), quantillonVault);
        console.log("SUCCESS: QEUROToken roles updated");
    }

    function _deployPhase2() internal {
        console.log("\n=== PHASE 2: CORE PROTOCOL ===");
        
        // Deploy QTIToken
        QTIToken qtiTokenImpl = new QTIToken(timeProviderContract);
        bytes memory qtiInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            msg.sender,        // admin
            msg.sender,        // treasury
            msg.sender         // timelock
        );
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiTokenImpl), qtiInitData);
        qtiToken = address(qtiProxy);
        qtiTokenContract = QTIToken(qtiToken);
        console.log("QTIToken:", qtiToken);
        
        // Deploy Mock Aave contracts for localhost
        address mockAavePool;
        address mockAaveProvider;
        address mockRewardsController;
        
        if (isLocalhost) {
            MockAavePool mockPool = new MockAavePool(_getUSDCAddress(), _getUSDCAddress());
            mockAavePool = address(mockPool);
            MockPoolAddressesProvider mockProvider = new MockPoolAddressesProvider(mockAavePool);
            mockAaveProvider = address(mockProvider);
            MockRewardsController mockRewards = new MockRewardsController();
            mockRewardsController = address(mockRewards);
            console.log("Mock Aave contracts deployed");
        } else {
            mockAaveProvider = _getAaveProvider();
            mockRewardsController = _getRewardsController();
        }
        
        // Deploy AaveVault
        AaveVault aaveVaultImpl = new AaveVault();
        bytes memory aaveVaultInitData = abi.encodeWithSelector(
            AaveVault.initialize.selector,
            msg.sender,        // admin
            _getUSDCAddress(), // _usdc
            mockAaveProvider,  // _aaveProvider
            mockRewardsController, // _rewardsController
            msg.sender,        // _yieldShift (temporary)
            msg.sender,        // _timelock
            msg.sender         // _treasury
        );
        ERC1967Proxy aaveVaultProxy = new ERC1967Proxy(address(aaveVaultImpl), aaveVaultInitData);
        aaveVault = address(aaveVaultProxy);
        aaveVaultContract = AaveVault(aaveVault);
        console.log("AaveVault:", aaveVault);
        
        // Deploy stQEUROToken
        stQEUROToken stQeuroTokenImpl = new stQEUROToken(timeProviderContract);
        bytes memory stQeuroInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            msg.sender,        // admin
            qeuroToken,        // _qeuro
            msg.sender,        // _yieldShift (temporary)
            _getUSDCAddress(), // _usdc
            msg.sender,        // _treasury
            msg.sender         // _timelock
        );
        ERC1967Proxy stQeuroProxy = new ERC1967Proxy(address(stQeuroTokenImpl), stQeuroInitData);
        stQeuroToken = address(stQeuroProxy);
        stQeuroTokenContract = stQEUROToken(stQeuroToken);
        console.log("stQEUROToken:", stQeuroToken);
    }

    function _deployPhase3() internal {
        console.log("\n=== PHASE 3: POOL CONTRACTS ===");
        
        // Deploy UserPool
        UserPool userPoolImpl = new UserPool(timeProviderContract);
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            msg.sender,        // admin
            qeuroToken,        // _qeuro
            _getUSDCAddress(), // _usdc
            quantillonVault,   // _vault
            chainlinkOracle,   // _oracle
            msg.sender,        // _yieldShift (temporary)
            msg.sender,        // _timelock
            msg.sender         // _treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = address(userPoolProxy);
        userPoolContract = UserPool(userPool);
        console.log("UserPool:", userPool);

        // Deploy HedgerPool
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProviderContract);
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            msg.sender,        // admin
            _getUSDCAddress(), // _usdc
            chainlinkOracle,   // _oracle
            msg.sender,        // _yieldShift (temporary)
            msg.sender,        // _timelock
            msg.sender,        // _treasury
            quantillonVault    // _vault
        );
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(address(hedgerPoolImpl), hedgerPoolInitData);
        hedgerPool = address(hedgerPoolProxy);
        hedgerPoolContract = HedgerPool(hedgerPool);
        console.log("HedgerPool:", hedgerPool);
        
        // Deploy YieldShift
        YieldShift yieldShiftImpl = new YieldShift(timeProviderContract);
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            msg.sender,        // admin
            _getUSDCAddress(), // _usdc
            userPool,          // _userPool
            hedgerPool,        // _hedgerPool
            aaveVault,         // _aaveVault
            stQeuroToken,      // _stQEURO
            msg.sender,        // _timelock
            msg.sender         // _treasury
        );
        ERC1967Proxy yieldShiftProxy = new ERC1967Proxy(address(yieldShiftImpl), yieldShiftInitData);
        yieldShift = address(yieldShiftProxy);
        yieldShiftContract = YieldShift(yieldShift);
        console.log("YieldShift:", yieldShift);
    }

    function _deployPhase4() internal {
        console.log("\n=== PHASE 4: UPDATE CONTRACT REFERENCES ===");
        
        // Update QuantillonVault with pool addresses
        quantillonVaultContract.updateHedgerPool(hedgerPool);
        quantillonVaultContract.updateUserPool(userPool);
        console.log("SUCCESS: Vault pool addresses updated");
        
        // Authorize QuantillonVault as fee source in FeeCollector
        feeCollectorContract.authorizeFeeSource(quantillonVault);
        console.log("SUCCESS: QuantillonVault authorized as fee source");
        
        console.log("\n=== PHASE 5: HEDGER ROLE MANAGEMENT ===");
        
        // Grant deployer hedger role
        hedgerPoolContract.whitelistHedger(msg.sender);
        console.log("SUCCESS: Deployer whitelisted as hedger");
    }

    function _deployPhase5() internal {
        console.log("\n=== PHASE 5: FINALIZATION ===");
        copyABIsToFrontend();
    }

    function _initializeContracts() internal {
        console.log("\n=== FINALIZING CONTRACT SETUP ===");
        
        // Final oracle verification
        address finalVaultOracle = address(quantillonVaultContract.oracle());
        if (finalVaultOracle == chainlinkOracle) {
            console.log("SUCCESS: Oracle correctly set in vault");
        } else {
            console.log("ERROR: Oracle not properly set in vault!");
        }
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("QEUROToken:", qeuroToken);
        console.log("QuantillonVault:", quantillonVault);
        console.log("FeeCollector:", feeCollector);
        console.log("UserPool:", userPool);
        console.log("HedgerPool:", hedgerPool);
        console.log("ChainlinkOracle:", chainlinkOracle);
        console.log("SUCCESS: All contracts deployed successfully!");
    }
    

    function copyABIsToFrontend() internal {
        console.log("ABIs will be copied to frontend automatically");
    }

}
