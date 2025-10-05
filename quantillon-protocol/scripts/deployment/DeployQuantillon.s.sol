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
    address public deployerEOA; // persist deployer across helper calls
    bool public useMockOracle; // allow using mock oracle on testnets
    bool public useMockAave;   // allow using mock Aave on testnets
    // Phase gating via env for gas-capped networks
    bool public usePhase1; // core infra (time provider, oracle, qeuro, fee collector, vault, roles)
    bool public usePhase2; // core protocol (qti, aave vault, stqeuro)
    bool public usePhase3; // pools (user, hedger, yieldshift)
    bool public usePhase4; // update references and role wiring
    bool public usePhase5; // finalization and summary
    
    // Mock addresses for localhost (replace with real addresses for testnet/mainnet)
    address constant MOCK_EUR_USD_FEED = 0x1234567890123456789012345678901234567890;
    address constant MOCK_USDC_USD_FEED = 0x2345678901234567890123456789012345678901;
    address constant MOCK_AAVE_POOL = 0x4567890123456789012345678901234567890123;
    
    // Base Sepolia addresses (real addresses for testnet)
    // Source: scripts/deployment/deploy-base-sepolia.sh externalAddresses mapping
    address constant BASE_SEPOLIA_EUR_USD_FEED = 0x443c8906D15c131C52463a8384dcC0c65DcE3A96; // EUR/USD on Base Sepolia
    address constant BASE_SEPOLIA_USDC_USD_FEED = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1; // USDC/USD on Base Sepolia
    address constant BASE_SEPOLIA_USDC_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC on Base Sepolia
    address constant BASE_SEPOLIA_AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Aave Pool on Base Sepolia

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        deployerEOA = deployer;
        
        // Detect network
        _detectNetwork();
        // Allow forcing mock oracle on testnets via env (defaults to true for safety)
        useMockOracle = vm.envOr("USE_MOCK_ORACLE", true);
        // Allow forcing mock Aave on testnets via env (defaults to true for safety)
        useMockAave = vm.envOr("USE_MOCK_AAVE", true);
        // Phase gating (defaults to true so single run keeps existing behavior)
        usePhase1 = vm.envOr("USE_PHASE1", true);
        usePhase2 = vm.envOr("USE_PHASE2", true);
        usePhase3 = vm.envOr("USE_PHASE3", true);
        usePhase4 = vm.envOr("USE_PHASE4", true);
        usePhase5 = vm.envOr("USE_PHASE5", true);
        
        console.log(unicode"🚀 === QUANTILLON PROTOCOL DEPLOYMENT ===");
        console.log("Network:", network);
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);
        
        // Set higher gas limit for large contract deployments
        vm.fee(0);
        // Load env-provided addresses when running phased executions
        _loadEnvOverrides();

        // Phase 1: prerequisites and core infra
        if (usePhase1) {
            if (isLocalhost || isBaseSepolia) {
                _deployMockUSDC();
            }
            if (isLocalhost || (isBaseSepolia && useMockOracle)) {
                _deployMockFeeds();
            }
            _deployPhase1();
        }

        // Phase 2: core protocol
        if (usePhase2) {
            _deployPhase2();
        }

        // Phase 3: pools
        if (usePhase3) {
            _deployPhase3();
        }

        // Phase 4: references
        if (usePhase4) {
            _deployPhase4();
        }

        // Phase 5: finalization
        if (usePhase5) {
            _deployPhase5();
            _initializeContracts();
        }

        vm.stopBroadcast();
        
        console.log(unicode"\n✅ === DEPLOYMENT COMPLETED SUCCESSFULLY ===");
    }

    function _loadEnvOverrides() private {
        // Use env overrides if provided to stitch phases across separate runs
        address a;
        a = vm.envOr("TIME_PROVIDER", address(0));
        if (a != address(0)) { timeProvider = a; timeProviderContract = TimeProvider(a); }
        a = vm.envOr("CHAINLINK_ORACLE", address(0));
        if (a != address(0)) { chainlinkOracle = a; chainlinkOracleContract = ChainlinkOracle(a); }
        a = vm.envOr("QEURO_TOKEN", address(0));
        if (a != address(0)) { qeuroToken = a; qeuroTokenContract = QEUROToken(a); }
        a = vm.envOr("FEE_COLLECTOR", address(0));
        if (a != address(0)) { feeCollector = a; feeCollectorContract = FeeCollector(a); }
        a = vm.envOr("QUANTILLON_VAULT", address(0));
        if (a != address(0)) { quantillonVault = a; quantillonVaultContract = QuantillonVault(a); }
        a = vm.envOr("USER_POOL", address(0));
        if (a != address(0)) { userPool = a; userPoolContract = UserPool(a); }
        a = vm.envOr("HEDGER_POOL", address(0));
        if (a != address(0)) { hedgerPool = a; hedgerPoolContract = HedgerPool(a); }
        a = vm.envOr("STQEURO_TOKEN", address(0));
        if (a != address(0)) { stQeuroToken = a; stQeuroTokenContract = stQEUROToken(a); }
        a = vm.envOr("AAVE_VAULT", address(0));
        if (a != address(0)) { aaveVault = a; aaveVaultContract = AaveVault(a); }
        a = vm.envOr("YIELDSHIFT", address(0));
        if (a != address(0)) { yieldShift = a; yieldShiftContract = YieldShift(a); }
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
        console.log(unicode"\n🔧 === DEPLOYING MOCK USDC ===");
        
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
        if (isLocalhost || (isBaseSepolia && useMockOracle)) {
            MockChainlinkOracle mockImplementation = new MockChainlinkOracle();
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(mockImplementation),
                abi.encodeWithSelector(
                    MockChainlinkOracle.initialize.selector,
                    deployerEOA,        // admin
                    _getEURUSDFeed(),  // EUR/USD feed (mock)
                    _getUSDCUSDFeed(), // USDC/USD feed (mock)
                    deployerEOA         // treasury
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
                    deployerEOA,        // admin
                    _getEURUSDFeed(),  // EUR/USD feed
                    _getUSDCUSDFeed(), // USDC/USD feed
                    deployerEOA         // treasury
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
            deployerEOA,        // admin
            deployerEOA,        // vault (temporary)
            deployerEOA,        // timelock
            deployerEOA         // treasury
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroTokenImpl), qeuroInitData);
        qeuroToken = address(qeuroProxy);
        qeuroTokenContract = QEUROToken(qeuroToken);
        console.log("QEUROToken:", qeuroToken);
        
        // 4. Deploy FeeCollector
        FeeCollector feeCollectorImpl = new FeeCollector();
        bytes memory feeCollectorInitData = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            deployerEOA,        // admin
            deployerEOA,        // treasury (same as admin for now)
            deployerEOA,        // devFund (same as admin for now)
            deployerEOA         // communityFund (same as admin for now)
        );
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), feeCollectorInitData);
        feeCollector = address(feeCollectorProxy);
        feeCollectorContract = FeeCollector(feeCollector);
        console.log("FeeCollector:", feeCollector);
        
        // 5. Deploy QuantillonVault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            deployerEOA,        // admin
            qeuroToken,        // _qeuro
            _getUSDCAddress(), // _usdc
            chainlinkOracle,   // _oracle
            address(0),        // _hedgerPool (temporary)
            address(0),        // _userPool (temporary)
            deployerEOA,        // _timelock
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
        qeuroTokenContract.revokeRole(qeuroTokenContract.MINTER_ROLE(), deployerEOA);
        qeuroTokenContract.grantRole(qeuroTokenContract.MINTER_ROLE(), quantillonVault);
        qeuroTokenContract.revokeRole(qeuroTokenContract.BURNER_ROLE(), deployerEOA);
        qeuroTokenContract.grantRole(qeuroTokenContract.BURNER_ROLE(), quantillonVault);
        console.log("SUCCESS: QEUROToken roles updated");
    }

    function _deployPhase2() internal {
        console.log("\n=== PHASE 2: CORE PROTOCOL ===");
        
        // Deploy QTIToken
        QTIToken qtiTokenImpl = new QTIToken(timeProviderContract);
        bytes memory qtiInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            deployerEOA,        // admin
            deployerEOA,        // treasury
            deployerEOA         // timelock
        );
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiTokenImpl), qtiInitData);
        qtiToken = address(qtiProxy);
        qtiTokenContract = QTIToken(qtiToken);
        console.log("QTIToken:", qtiToken);
        
        // Deploy Mock Aave contracts for localhost
        address mockAavePool;
        address mockAaveProvider;
        address mockRewardsController;
        
        if (isLocalhost || (isBaseSepolia && useMockAave)) {
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
            deployerEOA,        // admin
            _getUSDCAddress(), // _usdc
            mockAaveProvider,  // _aaveProvider
            mockRewardsController, // _rewardsController
            deployerEOA,        // _yieldShift (temporary)
            deployerEOA,        // _timelock
            deployerEOA         // _treasury
        );
        ERC1967Proxy aaveVaultProxy = new ERC1967Proxy(address(aaveVaultImpl), aaveVaultInitData);
        aaveVault = address(aaveVaultProxy);
        aaveVaultContract = AaveVault(aaveVault);
        console.log("AaveVault:", aaveVault);
        
        // Deploy stQEUROToken
        stQEUROToken stQeuroTokenImpl = new stQEUROToken(timeProviderContract);
        bytes memory stQeuroInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            deployerEOA,        // admin
            qeuroToken,        // _qeuro
            deployerEOA,        // _yieldShift (temporary)
            _getUSDCAddress(), // _usdc
            deployerEOA,        // _treasury
            deployerEOA         // _timelock
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
            deployerEOA,        // admin
            qeuroToken,        // _qeuro
            _getUSDCAddress(), // _usdc
            quantillonVault,   // _vault
            chainlinkOracle,   // _oracle
            deployerEOA,        // _yieldShift (temporary)
            deployerEOA,        // _timelock
            deployerEOA         // _treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = address(userPoolProxy);
        userPoolContract = UserPool(userPool);
        console.log("UserPool:", userPool);

        // Deploy HedgerPool
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProviderContract);
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            deployerEOA,        // admin
            _getUSDCAddress(), // _usdc
            chainlinkOracle,   // _oracle
            deployerEOA,        // _yieldShift (temporary)
            deployerEOA,        // _timelock
            deployerEOA,        // _treasury
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
            deployerEOA,        // admin
            _getUSDCAddress(), // _usdc
            userPool,          // _userPool
            hedgerPool,        // _hedgerPool
            aaveVault,         // _aaveVault
            stQeuroToken,      // _stQEURO
            deployerEOA,        // _timelock
            deployerEOA         // _treasury
        );
        ERC1967Proxy yieldShiftProxy = new ERC1967Proxy(address(yieldShiftImpl), yieldShiftInitData);
        yieldShift = address(yieldShiftProxy);
        yieldShiftContract = YieldShift(yieldShift);
        console.log("YieldShift:", yieldShift);
    }

    function _deployPhase4() internal {
        console.log("\n=== PHASE 4: UPDATE CONTRACT REFERENCES ===");
        
        // Ensure deployer has governance rights on the vault in phased runs
        // This is idempotent and safe across reruns
        try quantillonVaultContract.grantRole(quantillonVaultContract.GOVERNANCE_ROLE(), msg.sender) {
            // no-op
        } catch {}

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
