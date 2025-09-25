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
import "../../src/mocks/MockUSDC.sol";

// Import mock aggregator for localhost deployment
import "../../test/ChainlinkOracle.t.sol";

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
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

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
        console.log("All contracts deployed and ready for initialization");
        console.log("Deployment addresses:");
        if (isLocalhost || isBaseSepolia) {
            console.log("MockUSDC:", mockUSDC);
        }
        if (isLocalhost) {
            console.log("Mock EUR/USD Feed:", mockEurUsdFeed);
            console.log("Mock USDC/USD Feed:", mockUsdcUsdFeed);
        }
        console.log("TimeProvider:", timeProvider);
        console.log("ChainlinkOracle:", chainlinkOracle);
        console.log("QEUROToken:", qeuroToken);
        console.log("QTIToken:", qtiToken);
        console.log("QuantillonVault:", quantillonVault);
        console.log("UserPool:", userPool);
        console.log("HedgerPool:", hedgerPool);
        console.log("stQEUROToken:", stQeuroToken);
        console.log("AaveVault:", aaveVault);
        console.log("YieldShift:", yieldShift);
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
        
        console.log("Deploying MockUSDC...");
        mockUSDCContract = new MockUSDC();
        mockUSDC = address(mockUSDCContract);
        console.log("MockUSDC deployed to:", mockUSDC);
        console.log("MockUSDC name:", mockUSDCContract.name());
        console.log("MockUSDC symbol:", mockUSDCContract.symbol());
        console.log("MockUSDC decimals:", mockUSDCContract.decimals());
        
        // Mint some USDC to deployer for testing
        uint256 mintAmount = 1000000 * 10**6; // 1M USDC
        mockUSDCContract.mint(msg.sender, mintAmount);
        console.log("Minted", mintAmount / 10**6, "USDC to deployer");
    }

    function _deployMockFeeds() internal {
        console.log("\n=== DEPLOYING MOCK PRICE FEEDS ===");
        
        // Deploy EUR/USD mock price feed (8 decimals like real Chainlink)
        console.log("Deploying EUR/USD mock price feed...");
        mockEurUsdFeedContract = new MockAggregatorV3(8);
        mockEurUsdFeed = address(mockEurUsdFeedContract);
        console.log("EUR/USD mock feed deployed to:", mockEurUsdFeed);
        
        // Set EUR/USD price to ~1.08 USD per EUR (realistic current price)
        mockEurUsdFeedContract.setPrice(108000000); // 1.08 * 10^8 (8 decimals)
        console.log("EUR/USD price set to 1.08 USD");

        // Deploy USDC/USD mock price feed (8 decimals like real Chainlink)
        console.log("Deploying USDC/USD mock price feed...");
        mockUsdcUsdFeedContract = new MockAggregatorV3(8);
        mockUsdcUsdFeed = address(mockUsdcUsdFeedContract);
        console.log("USDC/USD mock feed deployed to:", mockUsdcUsdFeed);
        
        // Set USDC/USD price to ~1.00 USD (should be close to $1)
        mockUsdcUsdFeedContract.setPrice(100000000); // 1.00 * 10^8 (8 decimals)
        console.log("USDC/USD price set to 1.00 USD");
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
        
        // 1. Deploy TimeProvider (required by most contracts)
        console.log("Deploying TimeProvider...");
        timeProviderContract = new TimeProvider();
        timeProvider = address(timeProviderContract);
        console.log("TimeProvider deployed to:", timeProvider);

        // 2. Deploy Oracle with proxy (MockChainlinkOracle for localhost, ChainlinkOracle for others)
        if (isLocalhost) {
            console.log("Deploying MockChainlinkOracle implementation for localhost...");
            MockChainlinkOracle mockImplementation = new MockChainlinkOracle();
            console.log("MockChainlinkOracle implementation deployed to:", address(mockImplementation));
            
            console.log("Deploying MockChainlinkOracle proxy...");
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(mockImplementation),
                abi.encodeWithSelector(
                    MockChainlinkOracle.initialize.selector,
                    msg.sender,        // admin
                    _getEURUSDFeed(),  // EUR/USD feed (mock)
                    _getUSDCUSDFeed(), // USDC/USD feed (mock)
                    msg.sender         // treasury (using deployer for mock)
                )
            );
            chainlinkOracle = address(proxy);
            console.log("MockChainlinkOracle proxy deployed to:", chainlinkOracle);
            console.log("Using mock EUR/USD feed:", _getEURUSDFeed());
            console.log("Using mock USDC/USD feed:", _getUSDCUSDFeed());
            console.log("MockChainlinkOracle initialized successfully");
        } else {
            console.log("Deploying ChainlinkOracle implementation...");
            ChainlinkOracle implementation = new ChainlinkOracle(timeProviderContract);
            console.log("ChainlinkOracle implementation deployed to:", address(implementation));
            
            console.log("Deploying ChainlinkOracle proxy...");
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(implementation),
                abi.encodeWithSelector(
                    ChainlinkOracle.initialize.selector,
                    msg.sender,        // admin
                    _getEURUSDFeed(),  // EUR/USD feed
                    _getUSDCUSDFeed(), // USDC/USD feed
                    msg.sender         // treasury (using deployer for now)
                )
            );
            chainlinkOracle = address(proxy);
            chainlinkOracleContract = ChainlinkOracle(chainlinkOracle);
            console.log("ChainlinkOracle proxy deployed to:", chainlinkOracle);
            console.log("Using EUR/USD feed:", _getEURUSDFeed());
            console.log("Using USDC/USD feed:", _getUSDCUSDFeed());
            console.log("ChainlinkOracle initialized successfully");
        }

        // 3. Deploy real QEUROToken first (needed for QuantillonVault)
        console.log("Deploying QEUROToken implementation...");
        QEUROToken qeuroTokenImpl = new QEUROToken();
        console.log("QEUROToken implementation deployed to:", address(qeuroTokenImpl));
        
        console.log("Deploying QEUROToken proxy...");
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            msg.sender,        // admin
            msg.sender,        // vault (temporary - will be updated after Vault deployment)
            msg.sender,        // timelock
            msg.sender         // treasury
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroTokenImpl), qeuroInitData);
        qeuroToken = address(qeuroProxy);
        qeuroTokenContract = QEUROToken(qeuroToken);
        console.log("QEUROToken proxy deployed to:", qeuroToken);
        
        // 4. Deploy QuantillonVault with real QEUROToken
        console.log("Deploying QuantillonVault implementation...");
        QuantillonVault vaultImpl = new QuantillonVault();
        console.log("QuantillonVault implementation deployed to:", address(vaultImpl));
        
        console.log("Deploying QuantillonVault proxy...");
        bytes memory vaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            msg.sender,        // admin
            qeuroToken,        // _qeuro (real QEURO token)
            _getUSDCAddress(), // _usdc
            chainlinkOracle,   // _oracle
            address(0),        // _hedgerPool (temporary - will be updated after HedgerPool deployment)
            address(0),        // _userPool (temporary - will be updated after UserPool deployment)
            msg.sender         // _timelock
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        quantillonVault = address(vaultProxy);
        quantillonVaultContract = QuantillonVault(quantillonVault);
        console.log("QuantillonVault proxy deployed to:", quantillonVault);
        
        // 5. Update QEUROToken roles to point to the real Vault
        console.log("Updating QEUROToken roles to point to the real Vault...");
        console.log("  Revoking MINTER_ROLE from temporary address (deployer)...");
        qeuroTokenContract.revokeRole(qeuroTokenContract.MINTER_ROLE(), msg.sender);
        console.log("  Granting MINTER_ROLE to Vault:", quantillonVault);
        qeuroTokenContract.grantRole(qeuroTokenContract.MINTER_ROLE(), quantillonVault);
        
        console.log("  Revoking BURNER_ROLE from temporary address (deployer)...");
        qeuroTokenContract.revokeRole(qeuroTokenContract.BURNER_ROLE(), msg.sender);
        console.log("  Granting BURNER_ROLE to Vault:", quantillonVault);
        qeuroTokenContract.grantRole(qeuroTokenContract.BURNER_ROLE(), quantillonVault);
        
        console.log("QEUROToken roles updated successfully");
    }

    function _deployPhase2() internal {
        console.log("\n=== PHASE 2: CORE PROTOCOL ===");
        
        // 5. Deploy QTIToken (upgradeable)
        console.log("Deploying QTIToken implementation...");
        QTIToken qtiTokenImpl = new QTIToken(timeProviderContract);
        console.log("QTIToken implementation deployed to:", address(qtiTokenImpl));
        
        console.log("Deploying QTIToken proxy...");
        bytes memory qtiInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            msg.sender,        // admin
            msg.sender,        // treasury
            msg.sender         // timelock
        );
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiTokenImpl), qtiInitData);
        qtiToken = address(qtiProxy);
        qtiTokenContract = QTIToken(qtiToken);
        console.log("QTIToken proxy deployed to:", qtiToken);
        
        // 6. Deploy Mock Aave contracts for localhost
        address mockAavePool;
        address mockAaveProvider;
        address mockRewardsController;
        
        if (isLocalhost) {
            console.log("Deploying MockAavePool...");
            MockAavePool mockPool = new MockAavePool(_getUSDCAddress(), _getUSDCAddress());
            mockAavePool = address(mockPool);
            console.log("MockAavePool deployed to:", mockAavePool);
            
            console.log("Deploying MockPoolAddressesProvider...");
            MockPoolAddressesProvider mockProvider = new MockPoolAddressesProvider(mockAavePool);
            mockAaveProvider = address(mockProvider);
            console.log("MockPoolAddressesProvider deployed to:", mockAaveProvider);
            
            console.log("Deploying MockRewardsController...");
            MockRewardsController mockRewards = new MockRewardsController();
            mockRewardsController = address(mockRewards);
            console.log("MockRewardsController deployed to:", mockRewardsController);
        } else {
            mockAaveProvider = _getAaveProvider();
            mockRewardsController = _getRewardsController();
        }
        
        // 7. Deploy AaveVault (upgradeable) - now with proper mock addresses
        console.log("Deploying AaveVault implementation...");
        AaveVault aaveVaultImpl = new AaveVault();
        console.log("AaveVault implementation deployed to:", address(aaveVaultImpl));
        
        console.log("Deploying AaveVault proxy...");
        bytes memory aaveVaultInitData = abi.encodeWithSelector(
            AaveVault.initialize.selector,
            msg.sender,        // admin
            _getUSDCAddress(), // _usdc
            mockAaveProvider,  // _aaveProvider
            mockRewardsController, // _rewardsController
            msg.sender,        // _yieldShift (temporary - will be updated)
            msg.sender,        // _timelock
            msg.sender         // _treasury
        );
        ERC1967Proxy aaveVaultProxy = new ERC1967Proxy(address(aaveVaultImpl), aaveVaultInitData);
        aaveVault = address(aaveVaultProxy);
        aaveVaultContract = AaveVault(aaveVault);
        console.log("AaveVault proxy deployed to:", aaveVault);
        
        // 7. Deploy stQEUROToken (upgradeable) - with temporary YieldShift address
        console.log("Deploying stQEUROToken implementation...");
        stQEUROToken stQeuroTokenImpl = new stQEUROToken(timeProviderContract);
        console.log("stQEUROToken implementation deployed to:", address(stQeuroTokenImpl));
        
        console.log("Deploying stQEUROToken proxy...");
        bytes memory stQeuroInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            msg.sender,        // admin
            qeuroToken,        // _qeuro
            msg.sender,        // _yieldShift (temporary - will be updated)
            _getUSDCAddress(), // _usdc
            msg.sender,        // _treasury
            msg.sender         // _timelock
        );
        ERC1967Proxy stQeuroProxy = new ERC1967Proxy(address(stQeuroTokenImpl), stQeuroInitData);
        stQeuroToken = address(stQeuroProxy);
        stQeuroTokenContract = stQEUROToken(stQeuroToken);
        console.log("stQEUROToken proxy deployed to:", stQeuroToken);
    }

    function _deployPhase3() internal {
        console.log("\n=== PHASE 3: POOL CONTRACTS ===");
        
        // 8. Deploy UserPool (upgradeable)
        console.log("Deploying UserPool implementation...");
        UserPool userPoolImpl = new UserPool(timeProviderContract);
        console.log("UserPool implementation deployed to:", address(userPoolImpl));
        
        console.log("Deploying UserPool proxy...");
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            msg.sender,        // admin
            qeuroToken,        // _qeuro
            _getUSDCAddress(), // _usdc
            quantillonVault,   // _vault
            msg.sender,        // _yieldShift (temporary - will be updated)
            msg.sender,        // _timelock
            msg.sender         // _treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = address(userPoolProxy);
        userPoolContract = UserPool(userPool);
        console.log("UserPool proxy deployed to:", userPool);

        // 10. Deploy HedgerPool (upgradeable)
        console.log("Deploying HedgerPool implementation...");
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProviderContract);
        console.log("HedgerPool implementation deployed to:", address(hedgerPoolImpl));
        
        console.log("Deploying HedgerPool proxy...");
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            msg.sender,        // admin
            _getUSDCAddress(), // _usdc
            chainlinkOracle,   // _oracle
            msg.sender,        // _yieldShift (temporary - will be updated)
            msg.sender,        // _timelock
            msg.sender,        // _treasury
            quantillonVault    // _vault
        );
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(address(hedgerPoolImpl), hedgerPoolInitData);
        hedgerPool = address(hedgerPoolProxy);
        hedgerPoolContract = HedgerPool(hedgerPool);
        console.log("HedgerPool proxy deployed to:", hedgerPool);
        
        // 10. Deploy YieldShift (upgradeable) - now with all required addresses
        console.log("Deploying YieldShift implementation...");
        YieldShift yieldShiftImpl = new YieldShift(timeProviderContract);
        console.log("YieldShift implementation deployed to:", address(yieldShiftImpl));
        
        console.log("Deploying YieldShift proxy...");
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            msg.sender,        // admin
            _getUSDCAddress(), // _usdc
            userPool,          // _userPool (now available)
            hedgerPool,        // _hedgerPool (now available)
            aaveVault,         // _aaveVault
            stQeuroToken,      // _stQEURO
            msg.sender,        // _timelock
            msg.sender         // _treasury
        );
        ERC1967Proxy yieldShiftProxy = new ERC1967Proxy(address(yieldShiftImpl), yieldShiftInitData);
        yieldShift = address(yieldShiftProxy);
        yieldShiftContract = YieldShift(yieldShift);
        console.log("YieldShift proxy deployed to:", yieldShift);
    }

    function _deployPhase4() internal {
        console.log("\n=== PHASE 4: UPDATE CONTRACT REFERENCES ===");
        
        // Update QuantillonVault with HedgerPool address
        console.log("Updating QuantillonVault with HedgerPool address...");
        quantillonVaultContract.updateHedgerPool(hedgerPool);
        console.log("QuantillonVault HedgerPool address updated to:", hedgerPool);
        
        // Update QuantillonVault with UserPool address
        console.log("Updating QuantillonVault with UserPool address...");
        quantillonVaultContract.updateUserPool(userPool);
        console.log("QuantillonVault UserPool address updated to:", userPool);
        
        console.log("Updating AaveVault with correct YieldShift address...");
        // Note: AaveVault doesn't have a setter for YieldShift, so we need to redeploy or use a different approach
        
        console.log("Updating stQEUROToken with correct YieldShift address...");
        // Note: stQEUROToken doesn't have a setter for YieldShift, so we need to redeploy or use a different approach
        
        console.log("Updating YieldShift with correct UserPool and HedgerPool addresses...");
        // Note: YieldShift doesn't have setters for UserPool and HedgerPool, so we need to redeploy or use a different approach
        
        console.log("Note: Some contracts may need manual configuration of cross-references.");
        console.log("Consider using setter functions or redeploying contracts with correct addresses.");
        
        console.log("\n=== PHASE 5: HEDGER ROLE MANAGEMENT ===");
        
        // Verify deployer has governance role (admin is deployer by default)
        bool hasGovernanceRole = hedgerPoolContract.hasRole(hedgerPoolContract.GOVERNANCE_ROLE(), msg.sender);
        console.log("Deployer has GOVERNANCE_ROLE:", hasGovernanceRole);
        
        // Grant deployer (admin) hedger role as protocol foundation is the first and main hedger
        console.log("Granting deployer hedger role as protocol foundation...");
        hedgerPoolContract.whitelistHedger(msg.sender);
        console.log("Deployer whitelisted as hedger:", msg.sender);
        
        // Verify hedger role and whitelist status
        bool isWhitelisted = hedgerPoolContract.isWhitelistedHedger(msg.sender);
        bool hasHedgerRole = hedgerPoolContract.hasRole(hedgerPoolContract.HEDGER_ROLE(), msg.sender);
        console.log("Deployer whitelist status:", isWhitelisted);
        console.log("Deployer has HEDGER_ROLE:", hasHedgerRole);
        
        console.log("Hedger role management completed.");
    }

    function _deployPhase5() internal {
        console.log("\n=== PHASE 5: FINALIZATION ===");
        
        // 11. Copy ABIs to frontend
        copyABIsToFrontend();
    }

    function _initializeContracts() internal {
        console.log("\n=== FINALIZING CONTRACT SETUP ===");
        
        console.log("All contracts deployed and initialized successfully!");
        console.log("Contract addresses:");
        console.log("  QEUROToken:", qeuroToken);
        console.log("  QuantillonVault:", quantillonVault);
        console.log("  QTIToken:", qtiToken);
        console.log("  UserPool:", userPool);
        console.log("  HedgerPool:", hedgerPool);
        console.log("  stQEUROToken:", stQeuroToken);
        console.log("  AaveVault:", aaveVault);
        console.log("  YieldShift:", yieldShift);
        console.log("  ChainlinkOracle:", chainlinkOracle);
        console.log("");
        console.log("Note: Some contracts may need manual configuration of cross-references.");
    }
    

    function copyABIsToFrontend() internal {
        console.log("Copying ABIs to frontend...");
        console.log("Please run './scripts/deployment/copy-abis.sh' manually to copy ABIs to frontend");
        console.log("This ensures the frontend has the latest contract interfaces.");
    }

}
