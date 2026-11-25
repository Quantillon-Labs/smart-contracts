// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IChainlinkOracle} from "../../src/interfaces/IChainlinkOracle.sol";
import {MockChainlinkOracle} from "../../src/mocks/MockChainlinkOracle.sol";
import {HedgerPool} from "../../src/core/HedgerPool.sol";
import {QuantillonVault} from "../../src/core/QuantillonVault.sol";
import {QEUROToken} from "../../src/core/QEUROToken.sol";
import {UserPool} from "../../src/core/UserPool.sol";
import {FeeCollector} from "../../src/core/FeeCollector.sol";
import {TimeProvider} from "../../src/libraries/TimeProviderLibrary.sol";
import {HedgerPoolLogicLibrary} from "../../src/libraries/HedgerPoolLogicLibrary.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {DeploymentHelpers} from "../deployment/DeploymentHelpers.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockAggregatorV3} from "../../src/mocks/MockAggregatorV3.sol";

/**
 * @title StateTrackerScenario3
 * @notice Script to replay scenario 3: 10-step test scenario with redemptions and margin addition
 * @dev Executes the scenario step by step and logs all statistics to console
 * 
 * @dev SCENARIO DESCRIPTION:
 * 
 * This script replays a test scenario that exercises the Quantillon Protocol
 * through hedger operations, user minting, oracle price changes, and multiple redemptions.
 * 
 * The scenario tests:
 * 1. Hedger position opening with initial collateral
 * 2. User QEURO minting with USDC deposit
 * 3. Oracle price increase and its effect on hedger P&L
 * 4. Multiple user redemptions and their impact on hedger positions
 * 
 * STEP-BY-STEP SCENARIO:
 * 
 * Step 1: Hedger deposits 50 USDC at 5% margin (20x leverage)
 *   - Oracle is at 1.00 USD/EUR (set during deployment)
 *   - Opens a hedger position with initial collateral
 *   - Position size = 50 USDC * 20 = 1000 USDC capacity
 * 
 * Step 2: User mints QEURO for 1000 USDC
 *   - User deposits 1000 USDC to mint QEURO at current oracle price (1.00)
 *   - Hedger position gets filled proportionally
 * 
 * Step 3: Oracle price → 1.04 USD/EUR
 *   - Price increase affects hedger unrealized P&L
 * 
 * Step 4: User redeems 500 QEURO
 *   - Redemption operation
 *   - Tests hedger position unwinding and realized P&L
 * 
 * Step 5: User redeems 100 QEURO
 *   - Additional redemption operation
 * 
 * Step 6: User redeems 100 QEURO
 *   - Additional redemption operation
 * 
 * Step 7: User redeems 100 QEURO
 *   - Additional redemption operation
 * 
 * Step 8: User redeems 100 QEURO
 *   - Additional redemption operation
 * 
 * Step 9: Hedger adds 50 USDC at 5% margin to its collateral
 *   - Hedger adds margin to existing position
 *   - Oracle price still at 1.04
 * 
 * Step 10: User redeems all its QEURO left
 *   - Final redemption operation - redeems all remaining QEURO balance
 * 
 * @dev STATISTICS CAPTURED:
 * 
 * At each step, the script captures:
 * - Oracle price (EUR/USD in 18 decimals and formatted)
 * - QEURO total supply
 * - Total USDC held in vault
 * - Total hedger margin
 * - Total hedger exposure
 * - Protocol collateralization ratio (basis points)
 * - Is protocol collateralized (boolean)
 * - Active hedgers count
 * - Hedger position details:
 *   * Position ID, margin, position size
 *   * Filled volume (actual exposure)
 *   * QEURO backed by position
 *   * Unrealized P&L
 *   * Realized P&L
 *   * Entry price, leverage
 * 
 */
contract StateTrackerScenario3 is Script {
    // Contract addresses (deployed fresh each run)
    address public HEDGER_POOL;
    address public VAULT;
    address public USER_POOL;
    address public QEURO;
    address public USDC;
    address public ORACLE;
    address public MOCK_EUR_USD_FEED;
    address public MOCK_USDC_USD_FEED;
    address public TIME_PROVIDER;
    address public FEE_COLLECTOR;

    // Test accounts
    address public hedger;
    address public user;

    // Scenario step counter
    uint256 public stepCounter = 0;
    
    // Track latest position ID opened by hedger
    uint256 public latestPositionId = 0;
    // Always use single hedger (simplified architecture)
    
    // Track hedger's net margin deposits (for calculating unrealized P&L when all QEURO is redeemed)
    uint256 public hedgerNetDeposits = 0; // 6 decimals (USDC)
    
    // Track cumulative P&L for when position is fully closed (contract resets P&L tracking)
    // When all QEURO is redeemed, contract adds realized P&L back to margin, so we need to track it ourselves
    int256 public lastKnownRealizedPnL = 0; // 6 decimals (USDC)
    int256 public lastKnownUnrealizedPnL = 0; // 6 decimals (USDC)

    struct ProtocolStats {
        uint256 step;
        string action;
        // Protocol statistics
        uint256 oraclePrice; // 18 decimals
        uint256 qeuroMinted; // 18 decimals (totalSupply)
        uint256 qeuroMintable; // 18 decimals (calculated)
        uint256 userCollateral; // 6 decimals (user deposits)
        uint256 hedgerCollateral; // 6 decimals (hedger margin)
        uint256 collateralizationPercentage; // 18 decimals (collateralizationRatio, e.g., 109183495000000000000 = 109.183495%)
        uint256 protocolTreasury; // 6 decimals - USDC balance in FeeCollector (protocol fees)
        // Hedger statistics
        uint256 hedgerEntryPrice; // 18 decimals
        int256 hedgerRealizedPnL; // 6 decimals
        int256 hedgerUnrealizedPnL; // 6 decimals
        int256 hedgerTotalPnL; // 6 decimals
        uint256 hedgerAvailableCollateral; // 6 decimals
        uint256 hedgerMaxWithdrawable; // 6 decimals - maximum USDC amount hedger can withdraw
        uint256 qeuroShare; // 18 decimals - QEURO share redeemed from hedger position (only relevant during redemption)
        uint256 usdcReturned; // 6 decimals - USDC amount returned to user during redemption (only relevant during redemption)
    }

    ProtocolStats[] public stats;
    
    // Constants matching QuantillonVault
    uint256 private constant CRITICAL_COLLATERALIZATION_RATIO_BPS = 10100; // 101.000000% (basis points)

    /**
     * @notice Deploys all contracts needed for the scenario
     * @dev Deploys Phase A (TimeProvider, Oracle, QEURO, Vault) and Phase C (UserPool, HedgerPool)
     */
    function _deployContracts(uint256 mintFee) internal {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        (bool isLocalhost, ) = DeploymentHelpers.detectNetwork(block.chainid);
        
        console2.log("=== Deploying Contracts ===");
        console2.log("Deployer:", deployer);
        console2.log("ChainId:", block.chainid);
        console2.log("");
        
        // Deploy TimeProvider
        TimeProvider timeProvider = new TimeProvider();
        TIME_PROVIDER = address(timeProvider);
        console2.log("TimeProvider deployed:", TIME_PROVIDER);
        
        // Deploy USDC (mock for localhost)
        if (isLocalhost) {
            // Deploy mock USDC
            MockUSDC mockUSDC = new MockUSDC();
            USDC = address(mockUSDC);
            console2.log("MockUSDC deployed:", USDC);
        } else {
            USDC = DeploymentHelpers.selectUSDCAddress(false, block.chainid);
            console2.log("Using USDC:", USDC);
        }
        
        // Deploy Mock Oracle feeds (always use mocks for scenario)
        address eurUsdFeed;
        address usdcUsdFeed;
        uint256 initialEurUsdPrice;
        
        if (isLocalhost) {
            // Deploy mock feeds
            MockAggregatorV3 eurUsdMockFeed = new MockAggregatorV3(8);
            eurUsdFeed = address(eurUsdMockFeed);
            eurUsdMockFeed.setPrice(100000000); // 1.00 USD per EUR
            initialEurUsdPrice = 100 * 1e16;
            console2.log("EUR/USD mock feed deployed:", eurUsdFeed);
            
            MockAggregatorV3 usdcUsdMockFeed = new MockAggregatorV3(8);
            usdcUsdFeed = address(usdcUsdMockFeed);
            usdcUsdMockFeed.setPrice(100000000); // 1.00 USD per USDC
            MOCK_USDC_USD_FEED = usdcUsdFeed; // Store for JSON output
            console2.log("USDC/USD mock feed deployed:", usdcUsdFeed);
        } else {
            // Use real feeds (not needed for scenario, but for completeness)
            revert("Scenario only supports localhost deployment");
        }
        
        // Deploy ChainlinkOracle (Mock)
        MockChainlinkOracle oracleImpl = new MockChainlinkOracle();
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), bytes(""));
        ORACLE = address(oracleProxy);
        MockChainlinkOracle mockOracle = MockChainlinkOracle(payable(ORACLE));
        mockOracle.initialize(deployer, eurUsdFeed, usdcUsdFeed, deployer);
        // Keep mock-oracle deviation anchor aligned with the feed baseline.
        mockOracle.setPrice(initialEurUsdPrice);
        console2.log("Oracle deployed:", ORACLE);
        
        // Store mock feed address for price updates
        MOCK_EUR_USD_FEED = eurUsdFeed;
        
        // Deploy FeeCollector first (needed for QEURO initialization)
        address treasury = address(uint160(uint256(keccak256(abi.encodePacked("treasury", deployer)))));
        address devFund = address(uint160(uint256(keccak256(abi.encodePacked("devFund", deployer)))));
        address communityFund = address(uint160(uint256(keccak256(abi.encodePacked("communityFund", deployer)))));
        
        FeeCollector feeCollectorImpl = new FeeCollector();
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), bytes(""));
        address feeCollector = address(feeCollectorProxy);
        FEE_COLLECTOR = feeCollector;
        FeeCollector(feeCollector).initialize(deployer, treasury, devFund, communityFund);
        console2.log("FeeCollector deployed:", feeCollector);
        
        // Deploy QEURO
        QEUROToken qeuroImpl = new QEUROToken();
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImpl), bytes(""));
        QEURO = address(qeuroProxy);
        QEUROToken(QEURO).initialize(deployer, deployer, deployer, deployer, feeCollector);
        console2.log("QEURO deployed:", QEURO);
        
        // Deploy Vault
        QuantillonVault vaultImpl = new QuantillonVault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), bytes(""));
        VAULT = address(vaultProxy);
        QuantillonVault(VAULT).initialize(deployer, QEURO, USDC, ORACLE, address(0), address(0), deployer, feeCollector);
        QuantillonVault(VAULT).updatePriceCache();
        console2.log("Vault deployed:", VAULT);
        
        // Setup QEURO roles
        QEUROToken(QEURO).revokeRole(QEUROToken(QEURO).MINTER_ROLE(), deployer);
        QEUROToken(QEURO).grantRole(QEUROToken(QEURO).MINTER_ROLE(), VAULT);
        QEUROToken(QEURO).revokeRole(QEUROToken(QEURO).BURNER_ROLE(), deployer);
        QEUROToken(QEURO).grantRole(QEUROToken(QEURO).BURNER_ROLE(), VAULT);
        console2.log("QEURO roles configured");
        
        // Deploy UserPool
        UserPool userPoolImpl = new UserPool(timeProvider);
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), bytes(""));
        USER_POOL = address(userPoolProxy);
        UserPool(USER_POOL).initialize(deployer, QEURO, USDC, VAULT, ORACLE, address(0), deployer, deployer);
        console2.log("UserPool deployed:", USER_POOL);
        
        // Deploy HedgerPool
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProvider);
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(address(hedgerPoolImpl), bytes(""));
        HEDGER_POOL = address(hedgerPoolProxy);
        HedgerPool(HEDGER_POOL).initialize(deployer, USDC, address(0), address(0), deployer, deployer, VAULT);
        HedgerPool(HEDGER_POOL).configureDependencies(
            HedgerPool.HedgerDependencyConfig({
                treasury: deployer,
                vault: VAULT,
                oracle: ORACLE,
                yieldShift: deployer,
                feeCollector: feeCollector
            })
        );
        console2.log("HedgerPool deployed:", HEDGER_POOL);
        
        // Set the deployer as the single hedger
        // The deployer has GOVERNANCE_ROLE from initialization, so can set single hedger
        try HedgerPool(HEDGER_POOL).setSingleHedger(deployer) {
            console2.log("Single hedger set:", deployer);
        } catch {
            console2.log("WARNING: Could not set single hedger address");
        }
        
        // Wire Vault with Pool addresses (required for Vault to accept calls from pools)
        QuantillonVault(VAULT).updateHedgerPool(HEDGER_POOL);
        QuantillonVault(VAULT).updateUserPool(USER_POOL);
        console2.log("Vault wired with HedgerPool and UserPool");
        
        // Authorize Vault as fee source in FeeCollector
        FeeCollector(feeCollector).authorizeFeeSource(VAULT);
        console2.log("Vault authorized as fee source in FeeCollector");
        
        // Set custom mint and redemption fees from command line argument
        // Both fees are set to the same value
        QuantillonVault(VAULT).updateParameters(mintFee, mintFee);
        console2.log("Mint fee set to:", mintFee);
        console2.log("Redemption fee set to:", mintFee);
        
        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("All contracts deployed successfully!");
        console2.log("");
        console2.log("========================================");
        console2.log("DEPLOYED CONTRACT ADDRESSES");
        console2.log("========================================");
        console2.log("IMPORTANT: Update your frontend addresses.json with these addresses!");
        console2.log("");
        console2.log("For chainId 31337 (localhost):");
        console2.log("  TimeProvider:", TIME_PROVIDER);
        console2.log("  USDC:", USDC);
        console2.log("  MockEURUSD:", MOCK_EUR_USD_FEED);
        console2.log("  ChainlinkOracle:", ORACLE);
        console2.log("  QEUROToken:", QEURO);
        console2.log("  QuantillonVault:", VAULT);
        console2.log("  UserPool:", USER_POOL);
        console2.log("  HedgerPool:", HEDGER_POOL);
        console2.log("");
        console2.log("JSON format for addresses.json:");
        console2.log("{");
        console2.log("  \"31337\": {");
        console2.log("    \"name\": \"Anvil Localhost\",");
        console2.log("    \"isTestnet\": true,");
        console2.log("    \"contracts\": {");
        console2.log("      \"TimeProvider\": \"", TIME_PROVIDER, "\",");
        console2.log("      \"MockUSDC\": \"", USDC, "\",");
        console2.log("      \"MockEURUSD\": \"", MOCK_EUR_USD_FEED, "\",");
        console2.log("      \"ChainlinkOracle\": \"", ORACLE, "\",");
        console2.log("      \"QEUROToken\": \"", QEURO, "\",");
        console2.log("      \"QuantillonVault\": \"", VAULT, "\",");
        console2.log("      \"UserPool\": \"", USER_POOL, "\",");
        console2.log("      \"HedgerPool\": \"", HEDGER_POOL, "\"");
        console2.log("    }");
        console2.log("  }");
        console2.log("}");
        console2.log("");
        console2.log("========================================");
        console2.log("");
    }

    function run(uint256 mintFee) external {
        // mintFee parameter: fee in 18 decimals format
        // Usage: forge script ... --sig "run(uint256)" -- 0 (for 0% fee)
        //        forge script ... --sig "run(uint256)" -- 1000000000000000 (for 0.1% fee)
        //        forge script ... --sig "run(uint256)" -- 10000000000000000 (for 1% fee)
        // Use deployer's private key (same as deployment scripts)
        // This ensures the hedger position is visible in the UI when connected with the same account
        uint256 pk = vm.envUint("PRIVATE_KEY");
        hedger = vm.addr(pk);
        user = vm.addr(pk); // Using same account for simplicity (deployer account)

        // Read stop after step from environment variable (default to 10 to run all steps)
        uint256 stopAfterStep;
        try vm.envUint("STOP_AFTER_STEP") returns (uint256 step) {
            stopAfterStep = step;
        } catch {
            stopAfterStep = 10;
        }
        if (stopAfterStep < 1 || stopAfterStep > 10) {
            revert("STOP_AFTER_STEP must be between 1 and 10");
        }

        // Read start from step from environment variable (default to 1 to start from beginning)
        uint256 startFromStep;
        try vm.envUint("START_FROM_STEP") returns (uint256 step) {
            startFromStep = step;
        } catch {
            startFromStep = 1;
        }
        if (startFromStep < 1 || startFromStep > stopAfterStep) {
            revert("START_FROM_STEP must be between 1 and STOP_AFTER_STEP");
        }

        console2.log("=== Starting Scenario Replay ===");
        console2.log("Using deployer account (PRIVATE_KEY from env)");
        console2.log("Scenario mode: single hedger (simplified architecture)");
        if (startFromStep == stopAfterStep) {
            console2.log(string.concat("Running step ", vm.toString(startFromStep), " only"));
        } else if (startFromStep > 1 || stopAfterStep < 10) {
            console2.log(string.concat("Running steps ", vm.toString(startFromStep), " to ", vm.toString(stopAfterStep)));
        } else {
            console2.log("Running all 10 steps");
        }
        console2.log("");
        console2.log("========================================");
        console2.log("IMPORTANT: WALLET CONNECTION REQUIRED");
        console2.log("========================================");
        console2.log("To see positions in the UI, you MUST:");
        console2.log("  1. Connect your wallet with the SAME account that deployed contracts");
        console2.log("  2. Update frontend addresses.json with the deployed addresses (see below)");
        console2.log("");
        console2.log("Wallet Address (use this account in MetaMask):");
        console2.log("  Hedger/User Address:", hedger);
        console2.log("");
        console2.log("If using MetaMask:");
        console2.log("  1. Click account icon -> Import Account");
        console2.log("  2. Paste the private key from your PRIVATE_KEY env variable");
        console2.log("  3. Connect to Localhost:8545 network");
        console2.log("  4. Make sure frontend addresses.json is updated (see addresses below)");
        console2.log("  5. Refresh the UI");
        console2.log("========================================");
        console2.log("");

        // Start broadcasting transactions for deployment
        vm.startBroadcast(pk);

        // Deploy all contracts fresh
        _deployContracts(mintFee);

        // Verify protocol is in fresh state (non-fatal - continue even if checks fail)
        console2.log("--- Verifying Fresh State ---");
        uint256 initialSupply = 0;
        uint256 initialMargin = 0;
        uint256 initialExposure = 0;
        
        // Check QEURO totalSupply with comprehensive error handling
        try QEUROToken(QEURO).totalSupply() returns (uint256 supply) {
            initialSupply = supply;
            console2.log("Initial QEURO Supply:", initialSupply / 1e18);
        } catch Error(string memory) {
            console2.log("WARNING: Could not read QEURO totalSupply (revert with reason)");
        } catch (bytes memory) {
            console2.log("WARNING: Could not read QEURO totalSupply (low-level error)");
        }
        
        // Check HedgerPool totalMargin with comprehensive error handling
        try HedgerPool(HEDGER_POOL).totalMargin() returns (uint256 margin) {
            initialMargin = margin;
            console2.log("Initial Hedger Margin:", initialMargin / 1e6);
        } catch Error(string memory) {
            console2.log("WARNING: Could not read HedgerPool totalMargin (revert with reason)");
        } catch (bytes memory) {
            console2.log("WARNING: Could not read HedgerPool totalMargin (low-level error)");
        }
        
        // Check HedgerPool totalExposure with comprehensive error handling
        try HedgerPool(HEDGER_POOL).totalExposure() returns (uint256 exposure) {
            initialExposure = exposure;
            console2.log("Initial Hedger Exposure:", initialExposure / 1e6);
        } catch Error(string memory) {
            console2.log("WARNING: Could not read HedgerPool totalExposure (revert with reason)");
        } catch (bytes memory) {
            console2.log("WARNING: Could not read HedgerPool totalExposure (low-level error)");
        }
        
        // Check if critical contracts are deployed
        bool contractsDeployed = true;
        if (HEDGER_POOL.code.length == 0) {
            console2.log("");
            console2.log("ERROR: HedgerPool contract not deployed at expected address:", HEDGER_POOL);
            contractsDeployed = false;
        }
        if (VAULT.code.length == 0) {
            console2.log("");
            console2.log("ERROR: QuantillonVault contract not deployed at expected address:", VAULT);
            contractsDeployed = false;
        }
        if (QEURO.code.length == 0) {
            console2.log("");
            console2.log("ERROR: QEURO contract not deployed at expected address:", QEURO);
            contractsDeployed = false;
        }
        if (USDC.code.length == 0) {
            console2.log("");
            console2.log("ERROR: USDC contract not deployed at expected address:", USDC);
            contractsDeployed = false;
        }
        
        if (!contractsDeployed) {
            console2.log("");
            console2.log("CRITICAL: Required contracts are not deployed!");
            console2.log("Please deploy contracts before running scenario:");
            console2.log("  Use: ~/Github/restart-local-stack.sh localhost --with-mocks");
            console2.log("");
            console2.log("The scenario will likely fail if contracts are not deployed.");
            console2.log("");
        }
        
        if (initialSupply > 0 || initialMargin > 0 || initialExposure > 0) {
            console2.log("");
            console2.log("WARNING: Protocol is not in fresh state!");
            console2.log("Please redeploy contracts before running scenario.");
            console2.log("Use: ~/Github/restart-local-stack.sh localhost --with-mocks");
            console2.log("");
            console2.log("Proceeding anyway, but results may be inaccurate...");
        } else if (contractsDeployed) {
            console2.log("Protocol is in fresh state - ready to proceed");
        }
        console2.log("");

        // Continue with scenario steps (broadcast already started for deployment)
        // Oracle is already at 1.00 from deployment, no need to set it
        
        // Step 1: Hedger deposits 50 USDC at 5% margin
        if (1 >= startFromStep) _step1_HedgerDeposits50USDC();
        if (_shouldStop(1, startFromStep, stopAfterStep)) return;

        // Step 2: User mints QEURO for 1000 USDC
        if (2 >= startFromStep) _step2_UserMintsQEUROFor1000USDC();
        if (_shouldStop(2, startFromStep, stopAfterStep)) return;

        // Step 3: Oracle → 1.04
        if (3 >= startFromStep) _step3_SetOraclePrice(104 * 1e16); // 1.04
        if (_shouldStop(3, startFromStep, stopAfterStep)) return;

        // Step 4: User redeems 500 QEURO
        if (4 >= startFromStep) _step4_UserRedeems500QEURO();
        if (_shouldStop(4, startFromStep, stopAfterStep)) return;

        // Step 5: User redeems 100 QEURO
        if (5 >= startFromStep) _step5_UserRedeems100QEURO();
        if (_shouldStop(5, startFromStep, stopAfterStep)) return;

        // Step 6: User redeems 100 QEURO
        if (6 >= startFromStep) _step6_UserRedeems100QEURO();
        if (_shouldStop(6, startFromStep, stopAfterStep)) return;

        // Step 7: User redeems 100 QEURO
        if (7 >= startFromStep) _step7_UserRedeems100QEURO();
        if (_shouldStop(7, startFromStep, stopAfterStep)) return;

        // Step 8: User redeems 100 QEURO
        if (8 >= startFromStep) _step8_UserRedeems100QEURO();
        if (_shouldStop(8, startFromStep, stopAfterStep)) return;

        // Step 9: Hedger adds 50 USDC at 5% margin to its collateral
        if (9 >= startFromStep) _step9_HedgerAdds50USDC();
        if (_shouldStop(9, startFromStep, stopAfterStep)) return;

        // Step 10: User redeems all its QEURO left
        if (10 >= startFromStep) _step10_UserRedeemsAllQEURO();
        if (_shouldStop(10, startFromStep, stopAfterStep)) return;

        vm.stopBroadcast();

        // Write deployed addresses to file for frontend
        _writeAddressesToFile();

        // Note: Statistics are logged to console, no need to save to file
        // (vm.writeFile is not allowed in broadcast mode)

        // Summary logged in _saveStatisticsToFile
    }

    /**
     * @notice Checks if scenario should stop after current step
     * @param currentStep Current step number (1-10)
     * @param stopAfterStep Step number to stop after (1-10)
     * @return shouldStop True if execution should stop
     */
    function _shouldStop(uint256 currentStep, uint256 startFromStep, uint256 stopAfterStep) internal returns (bool shouldStop) {
        // Skip logging for steps before startFromStep
        if (currentStep < startFromStep) {
            return false;
        }
        if (currentStep >= stopAfterStep) {
            console2.log("");
            console2.log("========================================");
            console2.log(string.concat("Scenario stopped after step ", vm.toString(currentStep)));
            console2.log("========================================");
            console2.log("");
            vm.stopBroadcast();
            _writeAddressesToFile();
            return true;
        }
        return false;
    }

    /**
     * @notice Outputs deployed contract addresses in JSON format for frontend
     * @dev Outputs addresses.json format to console - bash script will capture and write to file
     */
    function _writeAddressesToFile() internal view {
        // Output addresses in a format that bash script can capture
        // Using a special marker so bash script can extract it
        console2.log("");
        console2.log("=== ADDRESSES_JSON_START ===");
        console2.log("{");
        console2.log("  \"31337\": {");
        console2.log("    \"name\": \"Anvil Localhost\",");
        console2.log("    \"isTestnet\": true,");
        console2.log("    \"contracts\": {");
        console2.log("      \"TimeProvider\": \"", vm.toString(TIME_PROVIDER), "\",");
        console2.log("      \"MockUSDC\": \"", vm.toString(USDC), "\",");
        console2.log("      \"USDC\": \"", vm.toString(USDC), "\",");
        console2.log("      \"MockEURUSD\": \"", vm.toString(MOCK_EUR_USD_FEED), "\",");
        console2.log("      \"MockUSDCUSD\": \"", vm.toString(MOCK_USDC_USD_FEED), "\",");
        console2.log("      \"ChainlinkOracle\": \"", vm.toString(ORACLE), "\",");
        console2.log("      \"MockChainlinkOracle\": \"", vm.toString(ORACLE), "\",");
        console2.log("      \"FeeCollector\": \"", vm.toString(FEE_COLLECTOR), "\",");
        console2.log("      \"QEUROToken\": \"", vm.toString(QEURO), "\",");
        console2.log("      \"QuantillonVault\": \"", vm.toString(VAULT), "\",");
        console2.log("      \"UserPool\": \"", vm.toString(USER_POOL), "\",");
        console2.log("      \"HedgerPool\": \"", vm.toString(HEDGER_POOL), "\"");
        console2.log("    }");
        console2.log("  }");
        console2.log("}");
        console2.log("=== ADDRESSES_JSON_END ===");
        console2.log("");
    }


    uint256 lastQeuroShare; // Track last qeuroShare from redemption events
    uint256 lastUsdcReturned; // Track last USDC amount returned from redemption events

    function _captureStats(string memory action) internal {
        stepCounter++;
        
        // Get basic protocol stats
        (uint256 price, uint256 qeuroMinted, uint256 userCollateral, uint256 hedgerCollateral, uint256 collateralizationPercentage, uint256 protocolTreasury) = _getProtocolStats();
        
        // Get hedger stats
        (uint256 hedgerEntryPrice, int256 hedgerRealizedPnL, int256 hedgerUnrealizedPnL, int256 hedgerTotalPnL, uint256 hedgerAvailableCollateral, uint256 hedgerMaxWithdrawable, uint256 qeuroMintable) = _getHedgerStats(price);

        ProtocolStats memory stat = ProtocolStats({
            step: stepCounter,
            action: action,
            oraclePrice: price,
            qeuroMinted: qeuroMinted,
            qeuroMintable: qeuroMintable,
            userCollateral: userCollateral,
            hedgerCollateral: hedgerCollateral,
            collateralizationPercentage: collateralizationPercentage,
            protocolTreasury: protocolTreasury,
            hedgerEntryPrice: hedgerEntryPrice,
            hedgerRealizedPnL: hedgerRealizedPnL,
            hedgerUnrealizedPnL: hedgerUnrealizedPnL,
            hedgerTotalPnL: hedgerTotalPnL,
            hedgerAvailableCollateral: hedgerAvailableCollateral,
            hedgerMaxWithdrawable: hedgerMaxWithdrawable,
            qeuroShare: lastQeuroShare,
            usdcReturned: lastUsdcReturned
        });
        
        // Reset qeuroShare and usdcReturned after capturing stats
        lastQeuroShare = 0;
        lastUsdcReturned = 0;

        stats.push(stat);
        
        // Track P&L for next step (used when position is fully closed)
        // Only update if there's still QEURO supply (otherwise we're using the tracked values)
        if (qeuroMinted > 0) {
            lastKnownRealizedPnL = hedgerRealizedPnL;
            lastKnownUnrealizedPnL = hedgerUnrealizedPnL;
        }

        // Log to console
        _logStats(stat);
    }

    function _getProtocolStats() internal returns (
        uint256 price,
        uint256 qeuroMinted,
        uint256 userCollateral,
        uint256 hedgerCollateral,
        uint256 collateralizationPercentage,
        uint256 protocolTreasury
    ) {
        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        QuantillonVault vault = QuantillonVault(VAULT);

        (price, ) = oracle.getEurUsdPrice();
        qeuroMinted = qeuroToken.totalSupply();
        hedgerCollateral = hedgerPool.totalMargin();
        
        // Get FeeCollector USDC balance (protocol treasury)
        IERC20 usdcToken = IERC20(USDC);
        if (FEE_COLLECTOR != address(0)) {
            protocolTreasury = usdcToken.balanceOf(FEE_COLLECTOR);
        } else {
            protocolTreasury = 0;
        }
        
        // User Collateral = actual USDC deposits made by users (net of fees)
        // This should only change during mint/redeem operations, not when oracle price moves
        // Calculate from vault's total USDC minus hedger collateral
        // Note: Protocol treasury (fees) is NOT in vault balance - it's in FeeCollector
        // So we only subtract hedger collateral from vault balance
        uint256 vaultUsdcBalance = usdcToken.balanceOf(VAULT);
        // Get aggregate external vault balance (Aave, Morpho, third-party adapters, ...)
        uint256 externalVaultBalance = vault.totalUsdcInExternalVaults();
        uint256 totalVaultUsdc = vaultUsdcBalance + externalVaultBalance;
        // User Collateral = Total Vault USDC - Hedger Collateral
        // The vault balance already contains net user deposits (after fees are taken)
        // Hedger collateral is also in the vault, so we subtract it to get user deposits
        unchecked {
            if (totalVaultUsdc >= hedgerCollateral) {
                userCollateral = totalVaultUsdc - hedgerCollateral;
            } else {
                userCollateral = 0; // Safety fallback
            }
        }
        uint256 collateralizationRatio = vault.getProtocolCollateralizationRatio();
        // Store as 18 decimals (e.g., 109183495000000000000 = 109.183495%) for maximum precision
        collateralizationPercentage = collateralizationRatio;
    }

    function _getHedgerStats(uint256 price) internal view returns (
        uint256 hedgerEntryPrice,
        int256 hedgerRealizedPnL,
        int256 hedgerUnrealizedPnL,
        int256 hedgerTotalPnL,
        uint256 hedgerAvailableCollateral,
        uint256 hedgerMaxWithdrawable,
        uint256 qeuroMintable
    ) {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        
        // Initialize values (single position model)
        hedgerEntryPrice = 0;
        hedgerRealizedPnL = int256(0);
        hedgerUnrealizedPnL = int256(0);
        hedgerTotalPnL = int256(0);
        hedgerAvailableCollateral = 0;
        hedgerMaxWithdrawable = 0;
        qeuroMintable = 0;
        
        // Get the single hedger's position ID
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;
        
        // Get core parameters
        (uint64 minMarginRatio, , , , , , , ) = hedgerPool.coreParams();
        
        // Get total supply
        QEUROToken qeuroToken = QEUROToken(QEURO);
        uint256 totalSupply = qeuroToken.totalSupply();
        
        // Get position data (single position model)
        (address positionHedger, , uint96 filledVolume, uint96 margin, uint96 entryPrice, , , , int128 realizedPnLFromContract, , bool isActive, uint128 qeuroBacked, ) = hedgerPool.positions(positionId);
        
        // If position doesn't exist or is not active, return zeros
        if (positionHedger != hedger || !isActive) {
            return (hedgerEntryPrice, hedgerRealizedPnL, hedgerUnrealizedPnL, hedgerTotalPnL, hedgerAvailableCollateral, hedgerMaxWithdrawable, qeuroMintable);
        }
        
        // Entry price (single position, no weighted average needed)
        hedgerEntryPrice = uint256(entryPrice);
        
        // Realized P&L
        // Note: When totalSupply = 0 (all QEURO redeemed), the contract resets P&L tracking
        // and adds cumulative realized P&L back to margin. We need to use our tracked values instead.
        hedgerRealizedPnL = int256(realizedPnLFromContract);
        
        // Calculate unrealized P&L for the position
        // NOTE: This matches the contract's HedgerPoolLogicLibrary.calculatePnL formula exactly
        // Formula: UnrealizedP&L = FilledVolume - QEUROBacked * OracleCurrentPrice
        int256 totalUnrealizedPnL;
        if (price == 0 || filledVolume == 0) {
            // Contract returns 0 when filledVolume == 0 (no exposure yet)
            // This covers no exposure yet (steps 1-2)
            totalUnrealizedPnL = int256(0);
        } else if (qeuroBacked == 0) {
            // When all QEURO is redeemed but filledVolume still exists,
            // the remaining filledVolume represents a loss that should be shown as unrealized P&L
            // This matches the contract's behavior: return -filledVolume when qeuroBacked == 0
            totalUnrealizedPnL = -int256(uint256(filledVolume));
        } else {
            // Calculate current value of QEURO backed (matching contract formula exactly)
            uint256 qeuroValueInUSDC = (uint256(qeuroBacked) * price) / 1e30;
            
            // P&L = filledVolume - qeuroValueInUSDC (matching contract exactly)
            // This changes with price movements - when price goes up, hedger loses
            if (uint256(filledVolume) >= qeuroValueInUSDC) {
                totalUnrealizedPnL = int256(uint256(filledVolume) - qeuroValueInUSDC);
            } else {
                totalUnrealizedPnL = -int256(qeuroValueInUSDC - uint256(filledVolume));
            }
        }
        
        // Check if protocol is in liquidation mode (CR <= 101%)
        // When protocol enters liquidation mode, the entirety of hedger collateral should be considered as unrealized P&L
        // For liquidation detection, use actual USDC in vault vs backing requirement (QEURO * price)
        bool isInLiquidation = false;
        if (totalSupply > 0 && price > 0) {
            // Calculate backing requirement (QEURO supply value in USDC at current price)
            uint256 backingRequirement = (totalSupply * price) / 1e30;
            
            // Get actual USDC in vault (user deposits + hedger margin)
            QuantillonVault vault = QuantillonVault(VAULT);
            uint256 vaultUsdcBalance = 0;
            uint256 externalVaultBalance = 0;
            try vault.totalUsdcHeld() returns (uint256 held) {
                vaultUsdcBalance = held;
            } catch {}
            try vault.totalUsdcInExternalVaults() returns (uint256 aave) {
                externalVaultBalance = aave;
            } catch {}
            uint256 totalActualCollateral = vaultUsdcBalance + externalVaultBalance;
            
            // Calculate collateralization ratio in basis points
            // CR = (totalActualCollateral / backingRequirement) * 10000 bps
            // Liquidation mode when CR <= CRITICAL_COLLATERALIZATION_RATIO_BPS (101%)
            if (backingRequirement > 0) {
                uint256 collateralizationRatioBps = (totalActualCollateral * 10000) / backingRequirement;
                isInLiquidation = collateralizationRatioBps <= CRITICAL_COLLATERALIZATION_RATIO_BPS;
            }
        }
        
        // Calculate unrealized P&L (mark-to-market of current position)
        // NOTE: Realized P&L is already reflected in the margin value, so we should NOT
        // subtract it here. The unrealized P&L is simply the current position's mark-to-market:
        // unrealizedPnL = filledVolume - (qeuroBacked * price)
        int256 positionUnrealizedPnL;
        if (isInLiquidation) {
            // In liquidation mode, the entire hedger margin is at risk (unrealized P&L)
            positionUnrealizedPnL = -int256(uint256(margin));
        } else if (totalSupply == 0 && lastKnownRealizedPnL != 0) {
            // Special case: All QEURO redeemed (position fully closed)
            // When all QEURO is redeemed, the contract adds realized P&L back to margin and resets P&L tracking.
            // We need to use our tracked cumulative values instead.
            // The cumulative realized P&L = previous realized + previous unrealized (which just got realized)
            hedgerRealizedPnL = lastKnownRealizedPnL + lastKnownUnrealizedPnL;
            positionUnrealizedPnL = int256(0); // No more position to mark-to-market
            
            // Calculate available collateral based on deposits and cumulative P&L
            // (not the inflated margin from contract which includes recovered filledVolume)
            int256 totalPnL = hedgerRealizedPnL;
            hedgerAvailableCollateral = uint256(int256(hedgerNetDeposits) + totalPnL);
            hedgerMaxWithdrawable = hedgerAvailableCollateral;
            hedgerUnrealizedPnL = positionUnrealizedPnL;
            hedgerTotalPnL = hedgerRealizedPnL + hedgerUnrealizedPnL;
            
            // QEURO mintable based on available collateral
            if (minMarginRatio > 0 && price > 0 && hedgerAvailableCollateral > 0) {
                uint256 numerator = hedgerAvailableCollateral * 10000 * 1e30;
                uint256 denominator = uint256(minMarginRatio) * price;
                if (denominator > 0) {
                    qeuroMintable = numerator / denominator;
                }
            }
            return (hedgerEntryPrice, hedgerRealizedPnL, hedgerUnrealizedPnL, hedgerTotalPnL, hedgerAvailableCollateral, hedgerMaxWithdrawable, qeuroMintable);
        } else if (filledVolume == 0) {
            // No exposure yet (steps 1-2): unrealized P&L is 0
            positionUnrealizedPnL = int256(0);
        } else {
            // Mark-to-market P&L of the current position
            // This is the gain/loss if the position were closed now
            positionUnrealizedPnL = totalUnrealizedPnL;
        }
        
        hedgerUnrealizedPnL = positionUnrealizedPnL;
        
        // Calculate effective margin for the position
        // NOTE: When margin is reduced due to realized losses, we should NOT include realizedPnL
        // in the effective margin calculation because the margin reduction already accounts for it.
        // The realized loss is "baked into" the margin value, so including realizedPnL would double-count it.
        // Effective margin = margin + unrealizedPnL (realizedPnL is already reflected in margin)
        // When unrealized profit is realized, it's added to margin by the contract, so margin already reflects it.
        int256 effectiveMargin = int256(uint256(margin)) + positionUnrealizedPnL;
        
        // Calculate required margin
        uint256 mintedExposure = (uint256(qeuroBacked) * price) / 1e30;
        uint256 hedgerRequiredMargin = (mintedExposure * uint256(minMarginRatio)) / 10000;
        
        // Calculate minimum margin (for max withdrawable)
        uint256 minimumMargin = 0;
        if (uint256(qeuroBacked) > 0 && price > 0 && minMarginRatio > 0) {
            minimumMargin = (mintedExposure * uint256(minMarginRatio)) / 10000;
        }
        
        // Calculate available collateral: effective margin - required margin
        if (effectiveMargin > int256(hedgerRequiredMargin)) {
            hedgerAvailableCollateral = uint256(effectiveMargin) - hedgerRequiredMargin;
        }
        
        // Calculate max withdrawable: effective margin - minimum margin
        // If position is undercollateralized (effective < required), max withdrawable is 0
        // because withdrawing would make the position even more undercollateralized
        if (effectiveMargin > int256(minimumMargin)) {
            hedgerMaxWithdrawable = uint256(effectiveMargin) - minimumMargin;
        } else {
            // Position is undercollateralized, cannot withdraw anything
            hedgerMaxWithdrawable = 0;
        }
        
        // Calculate total P&L
        hedgerTotalPnL = hedgerUnrealizedPnL + hedgerRealizedPnL;
        
        // Calculate QEURO mintable from available collateral
        if (minMarginRatio > 0 && price > 0 && hedgerAvailableCollateral > 0) {
            uint256 numerator = hedgerAvailableCollateral * 10000 * 1e30;
            uint256 denominator = uint256(minMarginRatio) * price;
            if (denominator > 0) {
                qeuroMintable = numerator / denominator;
            }
        }
    }

    function _formatPnL(int256 pnl) internal pure returns (string memory) {
        // P&L is in 6 decimals (USDC), format to show all 6 decimals
        // Example: 975700000 (6 decimals) = 975.700000 USDC
        bool isNegative = pnl < 0;
        uint256 absPnl = isNegative ? uint256(-pnl) : uint256(pnl);
        
        uint256 wholePart = absPnl / 1e6; // Get whole part
        uint256 remainder = absPnl % 1e6; // Get decimal remainder
        
        // Format decimal part with exactly 6 digits, extracting each digit individually
        string memory decimalStr = "";
        for (uint256 i = 0; i < 6; i++) {
            uint256 divisor = 10 ** (5 - i);
            uint256 digit = (remainder / divisor) % 10;
            decimalStr = string.concat(decimalStr, vm.toString(digit));
        }
        
        string memory sign = isNegative ? "-" : "";
        return string.concat(sign, vm.toString(wholePart), ".", decimalStr);
    }

    function _formatPnLForFile(int256 pnl) internal pure returns (string memory) {
        // Same as _formatPnL but for file output
        return _formatPnL(pnl);
    }

    function _formatUSDC(uint256 usdcAmount) internal pure returns (string memory) {
        // USDC is in 6 decimals, format to show all 6 decimals
        // Example: 50000000 (6 decimals) = 50.000000 USDC
        uint256 wholePart = usdcAmount / 1e6; // Get whole part
        uint256 remainder = usdcAmount % 1e6; // Get decimal remainder
        
        // Format decimal part with exactly 6 digits, extracting each digit individually
        string memory decimalStr = "";
        for (uint256 i = 0; i < 6; i++) {
            uint256 divisor = 10 ** (5 - i);
            uint256 digit = (remainder / divisor) % 10;
            decimalStr = string.concat(decimalStr, vm.toString(digit));
        }
        
        return string.concat(vm.toString(wholePart), ".", decimalStr);
    }

    function _formatQEURO(uint256 qeuroAmount) internal pure returns (string memory) {
        // QEURO is in 18 decimals, format to show all 18 decimals
        // Example: 197297290000000000000000 (18 decimals) = 197297.290000000000000000 QEURO
        uint256 wholePart = qeuroAmount / 1e18; // Get whole part
        uint256 remainder = qeuroAmount % 1e18; // Get decimal remainder
        
        // Format decimal part with exactly 18 digits, extracting each digit individually
        string memory decimalStr = "";
        for (uint256 i = 0; i < 18; i++) {
            uint256 divisor = 10 ** (17 - i);
            uint256 digit = (remainder / divisor) % 10;
            decimalStr = string.concat(decimalStr, vm.toString(digit));
        }
        
        return string.concat(vm.toString(wholePart), ".", decimalStr);
    }

    function _formatPrice(uint256 price) internal pure returns (string memory) {
        // Price is in 18 decimals, format to show all 18 decimals
        // Example: 1090000000000000000 (18 decimals) = 1.090000000000000000 USD
        uint256 wholePart = price / 1e18; // Get whole part
        uint256 remainder = price % 1e18; // Get decimal remainder
        
        // Format decimal part with exactly 18 digits, extracting each digit individually
        string memory decimalStr = "";
        for (uint256 i = 0; i < 18; i++) {
            uint256 divisor = 10 ** (17 - i);
            uint256 digit = (remainder / divisor) % 10;
            decimalStr = string.concat(decimalStr, vm.toString(digit));
        }
        
        return string.concat(vm.toString(wholePart), ".", decimalStr);
    }

    function _logStats(ProtocolStats memory stat) internal pure {
        console2.log("");
        console2.log("========================================");
        console2.log("STEP", stat.step);
        console2.log("Action:", stat.action);
        console2.log("========================================");
        console2.log("");
        console2.log("--- PROTOCOL STATISTICS ---");
        console2.log("  Oracle Price:", string.concat(_formatPrice(stat.oraclePrice), " USD"));
        console2.log("  QEURO Minted:", string.concat(_formatQEURO(stat.qeuroMinted), " QEURO"));
        console2.log("  QEURO Mintable:", string.concat(_formatQEURO(stat.qeuroMintable), " QEURO"));
        console2.log("  User Collateral:", string.concat(_formatUSDC(stat.userCollateral), " USDC"));
        console2.log("  Hedger Collateral:", string.concat(_formatUSDC(stat.hedgerCollateral), " USDC"));
        // Format as percentage with all 18 decimals from 18-decimal format
        // Input format: percentage * 1e18 (e.g., 109.183495% = 109183495000000000000)
        // The value represents: percentage_value * 1e18, so 100% = 1e20, 109.183495% = 109183495000000000000
        uint256 wholePart = stat.collateralizationPercentage / 1e18; // Get whole part (e.g., 109)
        uint256 remainder = stat.collateralizationPercentage % 1e18; // Get decimal remainder
        
        // Format decimal part with exactly 18 digits, padding with leading zeros
        // Extract each digit to ensure we always show exactly 18 decimal places
        string memory decimalStr = "";
        for (uint256 i = 0; i < 18; i++) {
            uint256 divisor = 10 ** (17 - i);
            uint256 digit = (remainder / divisor) % 10;
            decimalStr = string.concat(decimalStr, vm.toString(digit));
        }
        
        // Format the percentage string with all 18 decimal places
        string memory collatPct = string.concat(vm.toString(wholePart), ".", decimalStr, "%");
        console2.log("  Collateralization Percentage:", collatPct);
        console2.log("  Protocol Treasury:", string.concat(_formatUSDC(stat.protocolTreasury), " USDC"));
        console2.log("");
        console2.log("--- HEDGER STATISTICS ---");
        console2.log("  Hedger Entry Price:", string.concat(_formatPrice(stat.hedgerEntryPrice), " USD"));
        string memory realizedPnLStr = string.concat(_formatPnL(stat.hedgerRealizedPnL), " USDC");
        console2.log("  Hedger Realized P&L:", realizedPnLStr);
        string memory unrealizedPnLStr = string.concat(_formatPnL(stat.hedgerUnrealizedPnL), " USDC");
        console2.log("  Hedger Unrealized P&L:", unrealizedPnLStr);
        string memory totalPnLStr = string.concat(_formatPnL(stat.hedgerTotalPnL), " USDC");
        console2.log("  Hedger Total P&L:", totalPnLStr);
        console2.log("  Hedger Available Collateral:", string.concat(_formatUSDC(stat.hedgerAvailableCollateral), " USDC"));
        console2.log("  Hedger Max Withdrawable:", string.concat(_formatUSDC(stat.hedgerMaxWithdrawable), " USDC"));
        if (stat.qeuroShare > 0) {
            console2.log("  QEURO Share Redeemed:", string.concat(_formatQEURO(stat.qeuroShare), " QEURO"));
        }
        if (stat.usdcReturned > 0) {
            console2.log("  USDC Returned to User:", string.concat(_formatUSDC(stat.usdcReturned), " USDC"));
        }
        console2.log("");
    }

    /**
     * @notice Helper function to update oracle price incrementally to avoid triggering deviation checks
     * @dev Updates price in steps of max 1.5% (150 bps) to stay well below the 2% (200 bps) limit
     * @param targetPrice Target price in 18 decimals
     */
    function _setOraclePriceIncremental(uint256 targetPrice) internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        MockChainlinkOracle mockOracle = MockChainlinkOracle(payable(ORACLE));
        
        // Get current price from oracle
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Oracle price invalid");
        
        // If already at target, just update cache and return
        if (currentPrice == targetPrice) {
            mockOracle.setPrice(targetPrice);
            vault.updatePriceCache();
            return;
        }
        
        // Maximum step size: 1.5% (150 basis points) to stay well below 2% limit
        uint256 maxStepBps = 150; // 1.5%
        uint256 maxStepMultiplier = 10000 + maxStepBps; // 1.015
        
        // Update price incrementally until we reach target
        while (currentPrice != targetPrice) {
            uint256 nextPrice;
            
            if (currentPrice < targetPrice) {
                // Moving up: increase by max 1.5% or to target, whichever is smaller
                uint256 maxIncrease = (currentPrice * maxStepMultiplier) / 10000;
                nextPrice = maxIncrease < targetPrice ? maxIncrease : targetPrice;
            } else {
                // Moving down: decrease by max 1.5% or to target, whichever is larger
                uint256 maxDecrease = (currentPrice * (10000 - maxStepBps)) / 10000;
                nextPrice = maxDecrease > targetPrice ? maxDecrease : targetPrice;
            }
            
            // Set price on mock feed (8 decimals)
            int256 feedPrice = int256(nextPrice / 1e10);
            (bool success, ) = MOCK_EUR_USD_FEED.call(
                abi.encodeWithSignature("setPrice(int256)", feedPrice)
            );
            require(success, "Failed to set feed price");
            
            // Update timestamp
            (bool success2, ) = MOCK_EUR_USD_FEED.call(
                abi.encodeWithSignature("setUpdatedAt(uint256)", block.timestamp)
            );
            require(success2, "Failed to set updatedAt");

            // Keep mock oracle last-valid price in sync with feed updates.
            mockOracle.setPrice(nextPrice);
            
            // Update vault cache after each step
            vault.updatePriceCache();
            
            // Update current price for next iteration
            (currentPrice, isValid) = oracle.getEurUsdPrice();
            require(isValid, "Oracle price invalid");
        }
        
        console2.log("Price set to:", currentPrice / 1e16);
    }

    function _step1_HedgerDeposits50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        console2.log("--- Step 1: Opening Hedger Position ---");
        console2.log("Creating position for hedger address:", hedger);
        console2.log("NOTE: Connect your wallet to this address in the UI to see the position!");

        // Set the hedger as the single hedger if needed
        // The deployer should have GOVERNANCE_ROLE to set single hedger
        // Wrap in try-catch to handle cases where contract may not be deployed
        try HedgerPool(HEDGER_POOL).singleHedger() returns (address currentHedger) {
            if (currentHedger != hedger) {
                console2.log("Setting single hedger:", hedger);
                hedgerPool.setSingleHedger(hedger);
            } else {
                console2.log("Hedger already set as single hedger:", hedger);
            }
        } catch {
            console2.log("WARNING: Could not check or set single hedger");
        }

        // Approve USDC
        uint256 amount = 50 * 1e6; // 50 USDC
        usdcToken.approve(HEDGER_POOL, amount);
        console2.log(string.concat("USDC approved: ", vm.toString(amount / 1e6), " USDC"));

        // Open position with 5% margin (20x leverage)
        uint256 leverage = 20; // 5% margin = 20x leverage
        console2.log(string.concat("Opening position with leverage: ", vm.toString(leverage), "x"));
        
        try hedgerPool.enterHedgePosition(amount, leverage) returns (uint256 positionId) {
            latestPositionId = positionId;
            hedgerNetDeposits += amount; // Track deposit
            console2.log(string.concat("Position opened successfully! Position ID: ", vm.toString(positionId)));
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to open hedger position:", reason);
            console2.log("Make sure contracts are deployed and hedger is whitelisted if required.");
            revert(string.concat("Step 1 failed: ", reason));
        } catch (bytes memory) {
            console2.log("ERROR: Failed to open hedger position (low-level error)");
            console2.log("Make sure HedgerPool contract is deployed at:", HEDGER_POOL);
            revert("Step 1 failed: HedgerPool contract may not be deployed or call reverted");
        }
        console2.log("");

        _captureStats("Hedger deposits 50 USDC at 5% margin");
    }

    function _step2_UserMintsQEUROFor1000USDC() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        // User deposits 1000 USDC to mint QEURO
        // Protocol calculates QEURO amount: 1000 USDC / price (at 1.00, this is ~1000 QEURO minus fees)
        // Protocol takes fee from USDC deposit
        // User receives QEURO based on remaining USDC after fee
        
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC
        
        usdcToken.approve(VAULT, usdcAmount);
        vault.mintQEURO(usdcAmount, 0); // minQeuroOut = 0 for simplicity

        _captureStats("User mints QEURO for 1000 USDC");
    }

    function _step3_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.04");
    }

    function _step4_UserRedeems500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 500 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0); // minUsdcOut = 0
        
        // Check for events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 qeuroShareEventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
        bytes32 qeuroRedeemedEventSig = keccak256("QEURORedeemed(address,uint256,uint256)");
        bytes32 liquidationRedeemedEventSig = keccak256("LiquidationRedeemed(address,uint256,uint256,uint256,bool)");
        
        for (uint256 i = 0; i < logs.length; i++) {
            // Check for QeuroShareCalculated event
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroShareEventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                }
            }
            // Check for QEURORedeemed event to get USDC returned (normal redemption)
            // Event signature: QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcAmount)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcAmount) = abi.decode(logs[i].data, (uint256, uint256));
                    lastUsdcReturned = usdcAmount;
                }
            }
            // Check for LiquidationRedeemed event to get USDC returned (liquidation mode)
            // Event signature: LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcPayout, collateralizationRatioBps, isPremium)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == liquidationRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcPayout, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256, bool));
                    lastUsdcReturned = usdcPayout;
                }
            }
        }

        _captureStats("User redeems 500 QEURO");
    }

    function _step5_UserRedeems100QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 100 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0); // minUsdcOut = 0
        
        // Check for events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 qeuroShareEventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
        bytes32 qeuroRedeemedEventSig = keccak256("QEURORedeemed(address,uint256,uint256)");
        bytes32 liquidationRedeemedEventSig = keccak256("LiquidationRedeemed(address,uint256,uint256,uint256,bool)");
        
        for (uint256 i = 0; i < logs.length; i++) {
            // Check for QeuroShareCalculated event
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroShareEventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                }
            }
            // Check for QEURORedeemed event to get USDC returned (normal redemption)
            // Event signature: QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcAmount)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcAmount) = abi.decode(logs[i].data, (uint256, uint256));
                    lastUsdcReturned = usdcAmount;
                }
            }
            // Check for LiquidationRedeemed event to get USDC returned (liquidation mode)
            // Event signature: LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcPayout, collateralizationRatioBps, isPremium)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == liquidationRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcPayout, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256, bool));
                    lastUsdcReturned = usdcPayout;
                }
            }
        }

        _captureStats("User redeems 100 QEURO");
    }

    function _step6_UserRedeems100QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 100 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0); // minUsdcOut = 0
        
        // Check for events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 qeuroShareEventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
        bytes32 qeuroRedeemedEventSig = keccak256("QEURORedeemed(address,uint256,uint256)");
        bytes32 liquidationRedeemedEventSig = keccak256("LiquidationRedeemed(address,uint256,uint256,uint256,bool)");
        
        for (uint256 i = 0; i < logs.length; i++) {
            // Check for QeuroShareCalculated event
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroShareEventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                }
            }
            // Check for QEURORedeemed event to get USDC returned (normal redemption)
            // Event signature: QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcAmount)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcAmount) = abi.decode(logs[i].data, (uint256, uint256));
                    lastUsdcReturned = usdcAmount;
                }
            }
            // Check for LiquidationRedeemed event to get USDC returned (liquidation mode)
            // Event signature: LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcPayout, collateralizationRatioBps, isPremium)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == liquidationRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcPayout, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256, bool));
                    lastUsdcReturned = usdcPayout;
                }
            }
        }

        _captureStats("User redeems 100 QEURO");
    }

    function _step7_UserRedeems100QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 100 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0); // minUsdcOut = 0
        
        // Check for events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 qeuroShareEventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
        bytes32 qeuroRedeemedEventSig = keccak256("QEURORedeemed(address,uint256,uint256)");
        bytes32 liquidationRedeemedEventSig = keccak256("LiquidationRedeemed(address,uint256,uint256,uint256,bool)");
        
        for (uint256 i = 0; i < logs.length; i++) {
            // Check for QeuroShareCalculated event
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroShareEventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                }
            }
            // Check for QEURORedeemed event to get USDC returned (normal redemption)
            // Event signature: QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcAmount)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcAmount) = abi.decode(logs[i].data, (uint256, uint256));
                    lastUsdcReturned = usdcAmount;
                }
            }
            // Check for LiquidationRedeemed event to get USDC returned (liquidation mode)
            // Event signature: LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcPayout, collateralizationRatioBps, isPremium)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == liquidationRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcPayout, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256, bool));
                    lastUsdcReturned = usdcPayout;
                }
            }
        }

        _captureStats("User redeems 100 QEURO");
    }

    function _step8_UserRedeems100QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 100 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0); // minUsdcOut = 0
        
        // Check for events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 qeuroShareEventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
        bytes32 qeuroRedeemedEventSig = keccak256("QEURORedeemed(address,uint256,uint256)");
        bytes32 liquidationRedeemedEventSig = keccak256("LiquidationRedeemed(address,uint256,uint256,uint256,bool)");
        
        for (uint256 i = 0; i < logs.length; i++) {
            // Check for QeuroShareCalculated event
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroShareEventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                }
            }
            // Check for QEURORedeemed event to get USDC returned (normal redemption)
            // Event signature: QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcAmount)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcAmount) = abi.decode(logs[i].data, (uint256, uint256));
                    lastUsdcReturned = usdcAmount;
                }
            }
            // Check for LiquidationRedeemed event to get USDC returned (liquidation mode)
            // Event signature: LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcPayout, collateralizationRatioBps, isPremium)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == liquidationRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcPayout, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256, bool));
                    lastUsdcReturned = usdcPayout;
                }
            }
        }

        _captureStats("User redeems 100 QEURO");
    }

    function _step9_HedgerAdds50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        uint256 amount = 50 * 1e6; // 50 USDC
        usdcToken.approve(HEDGER_POOL, amount);
        
        // Add margin to existing position (position ID 1 from step 1)
        console2.log("--- Step 9: Adding Margin to Existing Position ---");
        console2.log("Adding 50 USDC to position ID 1 for hedger address:", hedger);
        
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;
        try hedgerPool.addMargin(positionId, amount) {
            hedgerNetDeposits += amount; // Track deposit
            console2.log("Margin added successfully to position ID 1");
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to add margin:", reason);
            revert(string.concat("Step 9 failed: ", reason));
        } catch (bytes memory) {
            console2.log("ERROR: Failed to add margin (low-level error)");
            revert("Step 9 failed: HedgerPool contract call reverted");
        }
        console2.log("");
        _captureStats("Hedger adds 50 USDC at 5% margin to its collateral");
    }

    function _step10_UserRedeemsAllQEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        // Get the user's (msg.sender's) current QEURO balance
        uint256 qeuroBalance = qeuroToken.balanceOf(msg.sender);
        
        // If user has no QEURO, skip redemption
        if (qeuroBalance == 0) {
            _captureStats("User redeems all its QEURO left (0 QEURO)");
            return;
        }
        
        qeuroToken.approve(VAULT, qeuroBalance);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroBalance, 0);
        
        // Check for events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 qeuroShareEventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
        bytes32 qeuroRedeemedEventSig = keccak256("QEURORedeemed(address,uint256,uint256)");
        bytes32 liquidationRedeemedEventSig = keccak256("LiquidationRedeemed(address,uint256,uint256,uint256,bool)");
        
        for (uint256 i = 0; i < logs.length; i++) {
            // Check for QeuroShareCalculated event
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroShareEventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                }
            }
            // Check for QEURORedeemed event to get USDC returned (normal redemption)
            // Event signature: QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcAmount)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == qeuroRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcAmount) = abi.decode(logs[i].data, (uint256, uint256));
                    lastUsdcReturned = usdcAmount;
                }
            }
            // Check for LiquidationRedeemed event to get USDC returned (liquidation mode)
            // Event signature: LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium)
            // user is indexed (in topics), so data contains: (qeuroAmount, usdcPayout, collateralizationRatioBps, isPremium)
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == liquidationRedeemedEventSig) {
                if (uint256(logs[i].topics[1]) == uint256(uint160(msg.sender))) {
                    (, uint256 usdcPayout, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256, bool));
                    lastUsdcReturned = usdcPayout;
                }
            }
        }

        _captureStats("User redeems all its QEURO left");
    }
}
