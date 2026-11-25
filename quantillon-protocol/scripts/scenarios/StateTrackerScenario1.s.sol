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
 * @title StateTrackerScenario1
 * @notice Script to replay scenario 1: comprehensive 26-step test scenario
 * @dev Executes the scenario step by step and logs all statistics to console
 * 
 * @dev SCENARIO DESCRIPTION:
 * 
 * This script replays a comprehensive test scenario that exercises the Quantillon Protocol
 * through various hedger operations, user minting/redeeming, and oracle price changes.
 * 
 * The scenario tests:
 * 1. Hedger position opening (multiple positions)
 * 2. User QEURO minting at different oracle prices
 * 3. User QEURO redemption and its impact on hedger positions
 * 4. Oracle price volatility and its effect on protocol state
 * 5. Hedger margin removal from positions
 * 
 * STEP-BY-STEP SCENARIO:
 * 
 * Step 1: Hedger deposits 50 USDC at 5% margin (20x leverage)
 *   - Oracle is at 1.08
 *   - Opens a hedger position with initial collateral
 *   - Position size = 50 USDC * 20 = 1000 USDC capacity
 * 
 * Step 2: Oracle price → 1.09 USD/EUR
 *   - Price increase
 * 
 * Step 3: User mints 500 QEURO
 *   - User deposits USDC to mint QEURO at current oracle price (1.09)
 *   - Hedger position gets filled proportionally
 * 
 * Step 4: Oracle price → 1.11 USD/EUR
 *   - Price increase
 * 
 * Step 5: Hedger adds 50 USD to its position
 *   - Hedger adds margin to existing position
 * 
 * Step 6: Oracle price → 1.13 USD/EUR
 *   - Price increase
 * 
 * Step 7: User mints 350 QEURO
 *   - Additional QEURO minting at higher price (1.13)
 * 
 * Step 8: Oracle price → 1.15 USD/EUR
 *   - Price increase
 * 
 * Step 9: User redeems 180 QEURO
 *   - Redemption operation
 *   - Tests hedger position unwinding and realized P&L
 * 
 * Step 10: Hedger deposits 50 more USD to its collateral
 *   - Hedger adds margin to position
 * 
 * Step 11: User mints 500 QEURO
 *   - Additional minting operation
 * 
 * Step 12: Oracle price → 1.12 USD/EUR
 *   - Price decrease
 * 
 * Step 13: Oracle price → 1.15 USD/EUR
 *   - Price increase
 * 
 * Step 14: Hedger adds 50 more USD to its collateral
 *   - Hedger adds margin to position
 * 
 * Step 15: Oracle price → 1.13 USD/EUR
 *   - Price decrease
 * 
 * Step 16: Oracle price → 1.11 USD/EUR
 *   - Price decrease
 * 
 * Step 17: User mints 1500 QEURO
 *   - Large mint operation
 * 
 * Step 18: Oracle price → 1.15 USD/EUR
 *   - Price increase
 * 
 * Step 19: User redeems 1000 QEURO
 *   - Large redemption operation
 * 
 * Step 20: Oracle price → 1.13 USD/EUR
 *   - Price decrease
 * 
 * Step 21: User redeems 1000 QEURO
 *   - Additional redemption operation
 * 
 * Step 22: Hedger removes 50 USD from its collateral
 *   - Hedger withdraws margin from position
 * 
 * Step 23: Oracle price → 1.16 USD/EUR
 *   - Price increase
 * 
 * Step 24: Hedger removes 20 USD from its collateral
 *   - Hedger withdraws additional margin
 * 
 * Step 25: Oracle price → 1.10 USD/EUR
 *   - Price decrease
 * 
 * Step 26: User redeems all his QEURO left
 *   - Final redemption operation
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
contract StateTrackerScenario1 is Script {
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
            eurUsdMockFeed.setPrice(108000000); // 1.08 USD per EUR
            initialEurUsdPrice = 108 * 1e16;
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

        // Read stop after step from environment variable (default to 26 to run all steps)
        uint256 stopAfterStep;
        try vm.envUint("STOP_AFTER_STEP") returns (uint256 step) {
            stopAfterStep = step;
        } catch {
            stopAfterStep = 26;
        }
        if (stopAfterStep < 1 || stopAfterStep > 26) {
            revert("STOP_AFTER_STEP must be between 1 and 26");
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
        } else if (startFromStep > 1 || stopAfterStep < 26) {
            console2.log(string.concat("Running steps ", vm.toString(startFromStep), " to ", vm.toString(stopAfterStep)));
        } else {
            console2.log("Running all 26 steps");
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
        // Step 1: Hedger deposits 50 USDC at 5% margin (Oracle at 1.08)
        if (1 >= startFromStep) _step1_HedgerDeposits50USDC();
        if (_shouldStop(1, startFromStep, stopAfterStep)) return;

        // Step 2: Oracle → 1.09
        if (2 >= startFromStep) _step2_SetOraclePrice(109 * 1e16); // 1.09
        if (_shouldStop(2, startFromStep, stopAfterStep)) return;

        // Step 3: User mints 500 QEURO
        if (3 >= startFromStep) _step3_UserMints500QEURO();
        if (_shouldStop(3, startFromStep, stopAfterStep)) return;

        // Step 4: Oracle → 1.11
        if (4 >= startFromStep) _step4_SetOraclePrice(111 * 1e16); // 1.11
        if (_shouldStop(4, startFromStep, stopAfterStep)) return;

        // Step 5: Hedger adds 50 USD to its position
        if (5 >= startFromStep) _step5_HedgerAdds50USDC();
        if (_shouldStop(5, startFromStep, stopAfterStep)) return;

        // Step 6: Oracle → 1.13
        if (6 >= startFromStep) _step6_SetOraclePrice(113 * 1e16); // 1.13
        if (_shouldStop(6, startFromStep, stopAfterStep)) return;

        // Step 7: User mints 350 QEURO
        if (7 >= startFromStep) _step7_UserMints350QEURO();
        if (_shouldStop(7, startFromStep, stopAfterStep)) return;

        // Step 8: Oracle → 1.15
        if (8 >= startFromStep) _step8_SetOraclePrice(115 * 1e16); // 1.15
        if (_shouldStop(8, startFromStep, stopAfterStep)) return;

        // Step 9: User redeems 180 QEURO
        if (9 >= startFromStep) _step9_UserRedeems180QEURO();
        if (_shouldStop(9, startFromStep, stopAfterStep)) return;

        // Step 10: Hedger deposits 50 more USD to its collateral
        if (10 >= startFromStep) _step10_HedgerAdds50USDC();
        if (_shouldStop(10, startFromStep, stopAfterStep)) return;

        // Step 11: User mints 500 QEURO
        if (11 >= startFromStep) _step11_UserMints500QEURO();
        if (_shouldStop(11, startFromStep, stopAfterStep)) return;

        // Step 12: Oracle → 1.12
        if (12 >= startFromStep) _step12_SetOraclePrice(112 * 1e16); // 1.12
        if (_shouldStop(12, startFromStep, stopAfterStep)) return;

        // Step 13: Oracle → 1.15
        if (13 >= startFromStep) _step13_SetOraclePrice(115 * 1e16); // 1.15
        if (_shouldStop(13, startFromStep, stopAfterStep)) return;

        // Step 14: Hedger adds 50 more USD to its collateral
        if (14 >= startFromStep) _step14_HedgerAdds50USDC();
        if (_shouldStop(14, startFromStep, stopAfterStep)) return;

        // Step 15: Oracle → 1.13
        if (15 >= startFromStep) _step15_SetOraclePrice(113 * 1e16); // 1.13
        if (_shouldStop(15, startFromStep, stopAfterStep)) return;

        // Step 16: Oracle → 1.11
        if (16 >= startFromStep) _step16_SetOraclePrice(111 * 1e16); // 1.11
        if (_shouldStop(16, startFromStep, stopAfterStep)) return;

        // Step 17: User mints 1500 QEURO
        if (17 >= startFromStep) _step17_UserMints1500QEURO();
        if (_shouldStop(17, startFromStep, stopAfterStep)) return;

        // Step 18: Oracle → 1.15
        if (18 >= startFromStep) _step18_SetOraclePrice(115 * 1e16); // 1.15
        if (_shouldStop(18, startFromStep, stopAfterStep)) return;

        // Step 19: User redeems 1000 QEURO
        if (19 >= startFromStep) _step19_UserRedeems1000QEURO();
        if (_shouldStop(19, startFromStep, stopAfterStep)) return;

        // Step 20: Oracle → 1.13
        if (20 >= startFromStep) _step20_SetOraclePrice(113 * 1e16); // 1.13
        if (_shouldStop(20, startFromStep, stopAfterStep)) return;

        // Step 21: User redeems 1000 QEURO
        if (21 >= startFromStep) _step21_UserRedeems1000QEURO();
        if (_shouldStop(21, startFromStep, stopAfterStep)) return;

        // Step 22: Hedger removes 50 USD from its collateral
        if (22 >= startFromStep) _step22_HedgerRemoves50USDC();
        if (_shouldStop(22, startFromStep, stopAfterStep)) return;

        // Step 23: Oracle → 1.16
        if (23 >= startFromStep) _step23_SetOraclePrice(116 * 1e16); // 1.16
        if (_shouldStop(23, startFromStep, stopAfterStep)) return;

        // Step 24: Hedger removes 20 USD from its collateral
        if (24 >= startFromStep) _step24_HedgerRemoves20USDC();
        if (_shouldStop(24, startFromStep, stopAfterStep)) return;

        // Step 25: Oracle → 1.10
        if (25 >= startFromStep) _step25_SetOraclePrice(110 * 1e16); // 1.10
        if (_shouldStop(25, startFromStep, stopAfterStep)) return;

        // Step 26: User redeems all his QEURO left
        if (26 >= startFromStep) _step26_UserRedeemsAllQEURO();
        if (_shouldStop(26, startFromStep, stopAfterStep)) return;

        vm.stopBroadcast();

        // Write deployed addresses to file for frontend
        _writeAddressesToFile();

        // Note: Statistics are logged to console, no need to save to file
        // (vm.writeFile is not allowed in broadcast mode)

        // Summary logged in _saveStatisticsToFile
    }

    /**
     * @notice Checks if scenario should stop after current step
     * @param currentStep Current step number (1-26)
     * @param startFromStep Step number to start from (1-26)
     * @param stopAfterStep Step number to stop after (1-26)
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
        hedgerRealizedPnL = int256(realizedPnLFromContract);
        
        // Calculate unrealized P&L for the position
        // NOTE: This matches the contract's HedgerPoolLogicLibrary.calculatePnL formula exactly
        // Formula: UnrealizedP&L = FilledVolume - QEUROBacked * OracleCurrentPrice
        int256 totalUnrealizedPnL;
        if (price == 0 || filledVolume == 0) {
            // Contract returns 0 when filledVolume == 0 (no exposure yet)
            // This covers both: no exposure yet (steps 1-2) and all QEURO redeemed with no remaining filledVolume
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
        
        // Calculate unrealized P&L based on protocol state
        // Different formulas apply depending on whether the protocol is in liquidation mode
        int256 positionUnrealizedPnL;
        if (isInLiquidation) {
            // In liquidation mode (CR <= 101%), the ENTIRE hedger margin is at stake
            // Unrealized P&L = -margin, meaning effectiveMargin = margin + (-margin) = 0
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
        } else if (realizedPnLFromContract != 0) {
            // Non-liquidation mode with realized P&L: subtract realized from total unrealized
            // This accounts for P&L that has already been settled during redemptions
            positionUnrealizedPnL = totalUnrealizedPnL - int256(realizedPnLFromContract);
        } else {
            // No realized P&L yet: use full mark-to-market
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

    function _step2_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.09");
    }

    /**
     * @notice Calculate USDC needed to mint target QEURO amount
     * @dev The protocol behavior is:
     *      - User wants to mint targetQeuro QEURO
     *      - Protocol calculates: usdcNeeded = targetQeuro * price / 1e30
     *      - User deposits usdcNeeded USDC
     *      - Protocol takes 0.1% fee from USDC deposit
     *      - Protocol mints QEURO from remaining USDC
     *      - User receives slightly less than targetQeuro (due to fee)
     *      Example: User wants 500 QEURO at 1.08 -> deposits 540 USDC -> receives ~499.5 QEURO
     * @param targetQeuro Target QEURO amount user wants to mint (in 18 decimals)
     * @param currentPrice Current EUR/USD price (in 18 decimals)
     * @return usdcNeeded USDC amount needed (in 6 decimals)
     */
    function _calculateUsdcNeededWithFee(uint256 targetQeuro, uint256 currentPrice) internal pure returns (uint256) {
        // Calculate USDC needed for target QEURO amount
        // usdcNeeded = targetQeuro * price / 1e30
        // The vault will automatically take 0.1% fee from this amount
        uint256 usdcNeeded = (targetQeuro * currentPrice) / 1e30;
        
        return usdcNeeded;
    }

    function _step3_UserMints500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        // User wants to mint 500 QEURO
        // Protocol calculates USDC needed: 500 * price
        // Protocol takes 0.1% fee from USDC deposit
        // User receives slightly less than 500 QEURO (e.g., ~499.5 QEURO at 1.08 price)
        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        // Calculate USDC needed for 500 QEURO (user will receive slightly less due to fee)
        uint256 targetQeuro = 500 * 1e18;
        uint256 usdcNeeded = _calculateUsdcNeededWithFee(targetQeuro, currentPrice);
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0); // minQeuroOut = 0 for simplicity

        _captureStats("User mints 500 QEURO");
    }

    function _step4_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.11");
    }

    function _step5_HedgerAdds50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        uint256 amount = 50 * 1e6; // 50 USDC
        usdcToken.approve(HEDGER_POOL, amount);
        
        // Add margin to existing position (position ID 1 from step 1)
        console2.log("--- Step 5: Adding Margin to Existing Position ---");
        console2.log("Adding 50 USDC to position ID 1 for hedger address:", hedger);
        
        try hedgerPool.addMargin(1, amount) {
            hedgerNetDeposits += amount; // Track deposit
            console2.log("Margin added successfully to position ID 1");
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to add margin:", reason);
            revert(string.concat("Step 5 failed: ", reason));
        } catch (bytes memory) {
            console2.log("ERROR: Failed to add margin (low-level error)");
            revert("Step 5 failed: HedgerPool contract call reverted");
        }
        console2.log("");
        _captureStats("Hedger adds 50 USDC to existing position");
    }

    function _step6_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.13");
    }

    function _step7_UserMints350QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        // Calculate USDC needed to get 350 QEURO after 0.1% fee
        uint256 targetQeuro = 350 * 1e18;
        uint256 usdcNeeded = _calculateUsdcNeededWithFee(targetQeuro, currentPrice);
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0);

        _captureStats("User mints 350 QEURO");
    }

    function _step8_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.15");
    }

    function _step9_UserRedeems180QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 180 * 1e18;
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

        _captureStats("User redeems 180 QEURO");
    }

    function _step10_HedgerAdds50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        uint256 amount = 50 * 1e6; // 50 USDC
        usdcToken.approve(HEDGER_POOL, amount);
        
        // Add margin to existing position (position ID 1 from step 1)
        console2.log("--- Step 10: Adding Margin to Existing Position ---");
        console2.log("Adding 50 USDC to position ID 1 for hedger address:", hedger);
        
        try hedgerPool.addMargin(1, amount) {
            hedgerNetDeposits += amount; // Track deposit
            console2.log("Margin added successfully to position ID 1");
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to add margin:", reason);
            revert(string.concat("Step 10 failed: ", reason));
        } catch (bytes memory) {
            console2.log("ERROR: Failed to add margin (low-level error)");
            revert("Step 10 failed: HedgerPool contract call reverted");
        }
        console2.log("");
        _captureStats("Hedger deposits 50 more USD to its collateral");
    }

    function _step11_UserMints500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        // Calculate USDC needed to get 500 QEURO after 0.1% fee
        uint256 targetQeuro = 500 * 1e18;
        uint256 usdcNeeded = _calculateUsdcNeededWithFee(targetQeuro, currentPrice);
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0);

        _captureStats("User mints 500 QEURO");
    }

    function _step12_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.12");
    }

    function _step13_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.15");
    }

    function _step14_HedgerAdds50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        uint256 amount = 50 * 1e6; // 50 USDC
        usdcToken.approve(HEDGER_POOL, amount);
        
        // Add margin to existing position (position ID 1 from step 1)
        console2.log("--- Step 14: Adding Margin to Existing Position ---");
        console2.log("Adding 50 USDC to position ID 1 for hedger address:", hedger);
        
        try hedgerPool.addMargin(1, amount) {
            hedgerNetDeposits += amount; // Track deposit
            console2.log("Margin added successfully to position ID 1");
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to add margin:", reason);
            revert(string.concat("Step 14 failed: ", reason));
        } catch (bytes memory) {
            console2.log("ERROR: Failed to add margin (low-level error)");
            revert("Step 14 failed: HedgerPool contract call reverted");
        }
        console2.log("");
        _captureStats("Hedger adds 50 more USD to its collateral");
    }

    function _step15_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.13");
    }

    function _step16_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.11");
    }

    function _step17_UserMints1500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        // Calculate USDC needed to get 1500 QEURO after 0.1% fee
        uint256 targetQeuro = 1500 * 1e18;
        uint256 usdcNeeded = _calculateUsdcNeededWithFee(targetQeuro, currentPrice);
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0);

        _captureStats("User mints 1500 QEURO");
    }

    function _step18_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.15");
    }

    function _step19_UserRedeems1000QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 1000 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0);
        
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

        _captureStats("User redeems 1000 QEURO");
    }

    function _step20_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.13");
    }

    function _step21_UserRedeems1000QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 1000 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated and QEURORedeemed events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0);
        
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

        _captureStats("User redeems 1000 QEURO");
    }

    function _step22_HedgerRemoves50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);

        uint256 amountToRemove = 50 * 1e6; // 50 USDC
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;
        
        console2.log("--- Step 22: Removing Margin from Position ---");
        console2.log(string.concat("Target: Remove ", vm.toString(amountToRemove / 1e6), " USDC from position ID: ", vm.toString(positionId)));
        
        // Get position data
        (address positionHedger, , , , , , , , , , bool isActive, , ) = hedgerPool.positions(positionId);
        
        // Verify position exists and is active
        if (positionHedger != hedger || !isActive) {
            console2.log("WARNING: Position not found or not active");
            _captureStats("Hedger removes 50 USDC from collateral (failed)");
            return;
        }
        
        // Try to remove margin (contract will enforce constraints)
        bool removalSucceeded = false;
        try hedgerPool.removeMargin(positionId, amountToRemove) {
            hedgerNetDeposits -= amountToRemove; // Track withdrawal
            console2.log(string.concat("Successfully removed ", vm.toString(amountToRemove / 1e6), " USDC from position"));
            removalSucceeded = true;
        } catch Error(string memory reason) {
            console2.log(string.concat("Failed to remove margin: ", reason));
            // Try with a small reduction (2% safety margin)
            if (amountToRemove > 2e6) {
                uint256 reducedAmount = amountToRemove * 98 / 100;
                try hedgerPool.removeMargin(positionId, reducedAmount) {
                    hedgerNetDeposits -= reducedAmount; // Track withdrawal
                    console2.log(string.concat("Removed ", vm.toString(reducedAmount / 1e6), " USDC (reduced amount)"));
                    removalSucceeded = true;
                } catch {
                    console2.log("Could not remove margin from position");
                }
            }
        } catch {
            console2.log("Could not remove margin from position");
        }

        // Update action description based on whether removal succeeded
        if (removalSucceeded) {
            _captureStats("Hedger removes 50 USDC from collateral");
        } else {
            _captureStats("Hedger attempts to remove 50 USDC from collateral (blocked - would make position liquidatable)");
        }
    }

    function _step23_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.16");
    }

    function _step24_HedgerRemoves20USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);

        uint256 amountToRemove = 20 * 1e6; // 20 USDC
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;
        
        console2.log("--- Step 24: Removing Margin from Position ---");
        console2.log(string.concat("Target: Remove ", vm.toString(amountToRemove / 1e6), " USDC from position ID: ", vm.toString(positionId)));
        
        // Get position data
        (address positionHedger, , , , , , , , , , bool isActive, , ) = hedgerPool.positions(positionId);
        
        // Verify position exists and is active
        if (positionHedger != hedger || !isActive) {
            console2.log("WARNING: Position not found or not active");
            _captureStats("Hedger removes 20 USDC from collateral (failed)");
            return;
        }
        
        // Try to remove margin (contract will enforce constraints)
        bool removalSucceeded = false;
        try hedgerPool.removeMargin(positionId, amountToRemove) {
            hedgerNetDeposits -= amountToRemove; // Track withdrawal
            console2.log(string.concat("Successfully removed ", vm.toString(amountToRemove / 1e6), " USDC from position"));
            removalSucceeded = true;
        } catch Error(string memory reason) {
            console2.log(string.concat("Failed to remove margin: ", reason));
            // Try with a small reduction (2% safety margin)
            if (amountToRemove > 2e6) {
                uint256 reducedAmount = amountToRemove * 98 / 100;
                try hedgerPool.removeMargin(positionId, reducedAmount) {
                    hedgerNetDeposits -= reducedAmount; // Track withdrawal
                    console2.log(string.concat("Removed ", vm.toString(reducedAmount / 1e6), " USDC (reduced amount)"));
                    removalSucceeded = true;
                } catch {
                    console2.log("Could not remove margin from position");
                }
            }
        } catch {
            console2.log("Could not remove margin from position");
        }

        // Update action description based on whether removal succeeded
        if (removalSucceeded) {
            _captureStats("Hedger removes 20 USDC from collateral");
        } else {
            _captureStats("Hedger attempts to remove 20 USDC from collateral (blocked - would make position liquidatable)");
        }
    }

    function _step25_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.10");
    }

    function _step26_UserRedeemsAllQEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        // Get the user's (msg.sender's) current QEURO balance
        uint256 qeuroBalance = qeuroToken.balanceOf(msg.sender);
        
        // If user has no QEURO, skip redemption
        if (qeuroBalance == 0) {
            _captureStats("User redeems all his QEURO left (0 QEURO)");
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

        _captureStats("User redeems all his QEURO left");
    }

    function _saveStatisticsToFile() internal {
        // Create formatted log file content
        string memory logContent = "========================================\n";
        logContent = string.concat(logContent, "QUANTILLON PROTOCOL - SCENARIO REPLAY RESULTS\n");
        logContent = string.concat(logContent, "========================================\n\n");
        logContent = string.concat(logContent, "Scenario: Test Scenario Replay\n");
        logContent = string.concat(logContent, "Total Steps: ", vm.toString(stepCounter), "\n");
        logContent = string.concat(logContent, "Execution Date: ", vm.toString(block.timestamp), "\n\n");
        
        for (uint256 i = 0; i < stats.length; i++) {
            ProtocolStats memory stat = stats[i];
            
            // Format collateralization percentage with all 18 decimals from 18-decimal format
            uint256 wholePart = stat.collateralizationPercentage / 1e18; // Get whole part
            uint256 remainder = stat.collateralizationPercentage % 1e18; // Get decimal remainder
            
            // Format decimal part with exactly 18 digits, extracting each digit individually
            // This ensures we always show exactly 18 decimal places, including trailing zeros
            string memory decimalStr = "";
            for (uint256 j = 0; j < 18; j++) {
                uint256 divisor = 10 ** (17 - j);
                uint256 digit = (remainder / divisor) % 10;
                decimalStr = string.concat(decimalStr, vm.toString(digit));
            }
            
            // Format the percentage string with all 18 decimal places
            string memory collatPctFormatted = string.concat(vm.toString(wholePart), ".", decimalStr);

            logContent = string.concat(
                logContent,
                "========================================\n",
                "STEP ", vm.toString(stat.step), ": ", stat.action, "\n",
                "========================================\n\n",
                "--- PROTOCOL STATISTICS ---\n",
                "  Oracle Price: ", _formatPrice(stat.oraclePrice), " USD\n",
                "  QEURO Minted: ", _formatQEURO(stat.qeuroMinted), " QEURO\n",
                "  QEURO Mintable: ", _formatQEURO(stat.qeuroMintable), " QEURO\n",
                "  User Collateral: ", _formatUSDC(stat.userCollateral), " USDC\n",
                "  Hedger Collateral: ", _formatUSDC(stat.hedgerCollateral), " USDC\n",
                "  Collateralization Percentage: ", collatPctFormatted, "%\n",
                "  Protocol Treasury: ", _formatUSDC(stat.protocolTreasury), " USDC\n",
                "\n",
                "--- HEDGER STATISTICS ---\n",
                "  Hedger Entry Price: ", _formatPrice(stat.hedgerEntryPrice), " USD\n",
                "  Hedger Realized P&L: ", _formatPnLForFile(stat.hedgerRealizedPnL), " USDC\n",
                "  Hedger Unrealized P&L: ", _formatPnLForFile(stat.hedgerUnrealizedPnL), " USDC\n",
                "  Hedger Total P&L: ", _formatPnLForFile(stat.hedgerTotalPnL), " USDC\n",
                "  Hedger Available Collateral: ", _formatUSDC(stat.hedgerAvailableCollateral), " USDC\n",
                "  Hedger Max Withdrawable: ", _formatUSDC(stat.hedgerMaxWithdrawable), " USDC\n",
                stat.qeuroShare > 0 ? string.concat("  QEURO Share Redeemed: ", _formatQEURO(stat.qeuroShare), " QEURO\n") : "",
                "\n"
            );
        }
        
        logContent = string.concat(logContent, "========================================\n");
        logContent = string.concat(logContent, "SCENARIO COMPLETE\n");
        logContent = string.concat(logContent, "========================================\n");
        
        // Save to results folder (Foundry allows writing to root, so we'll write there and move it)
        string memory filename = string.concat("scenario-", vm.toString(block.timestamp), ".log");
        vm.writeFile(filename, logContent);
        console2.log("\n=== SCENARIO COMPLETE ===");
        console2.log("Total steps executed:", stepCounter);
        console2.log("Results saved to:", filename);
        console2.log("Please move the file to scripts/results/ folder manually");
        
        // Summary already logged above
    }
}
