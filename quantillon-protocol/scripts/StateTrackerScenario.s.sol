// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IChainlinkOracle} from "../src/interfaces/IChainlinkOracle.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {FeeCollector} from "../src/core/FeeCollector.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {HedgerPoolLogicLibrary} from "../src/libraries/HedgerPoolLogicLibrary.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {DeploymentHelpers} from "./deployment/DeploymentHelpers.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockAggregatorV3} from "../test/ChainlinkOracle.t.sol";

/**
 * @title StateTrackerScenario
 * @notice Script to replay the test scenario and capture protocol statistics at each step
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
 * Step 26: User redeems 670 QEURO
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
 * @author Quantillon Labs
 */
contract StateTrackerScenario is Script {
    // Contract addresses (deployed fresh each run)
    address public HEDGER_POOL;
    address public VAULT;
    address public USER_POOL;
    address public QEURO;
    address public USDC;
    address public ORACLE;
    address public MOCK_EUR_USD_FEED;
    address public TIME_PROVIDER;
    address public FEE_COLLECTOR;

    // Test accounts
    address public hedger;
    address public user;

    // Scenario step counter
    uint256 public stepCounter = 0;
    
    // Track latest position ID opened by hedger
    uint256 public latestPositionId = 0;
    bool public useSinglePosition = false; // If true, add margin to existing position; if false, open new positions

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
    }

    ProtocolStats[] public stats;

    /**
     * @notice Deploys all contracts needed for the scenario
     * @dev Deploys Phase A (TimeProvider, Oracle, QEURO, Vault) and Phase C (UserPool, HedgerPool)
     */
    function _deployContracts(uint256 mintFee) internal {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        (bool isLocalhost, , ) = DeploymentHelpers.detectNetwork(block.chainid);
        
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
        
        if (isLocalhost) {
            // Deploy mock feeds
            MockAggregatorV3 eurUsdMockFeed = new MockAggregatorV3(8);
            eurUsdFeed = address(eurUsdMockFeed);
            eurUsdMockFeed.setPrice(108000000); // 1.08 USD per EUR
            console2.log("EUR/USD mock feed deployed:", eurUsdFeed);
            
            MockAggregatorV3 usdcUsdMockFeed = new MockAggregatorV3(8);
            usdcUsdFeed = address(usdcUsdMockFeed);
            usdcUsdMockFeed.setPrice(100000000); // 1.00 USD per USDC
            console2.log("USDC/USD mock feed deployed:", usdcUsdFeed);
        } else {
            // Use real feeds (not needed for scenario, but for completeness)
            revert("Scenario only supports localhost deployment");
        }
        
        // Deploy ChainlinkOracle (Mock)
        MockChainlinkOracle oracleImpl = new MockChainlinkOracle();
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), bytes(""));
        ORACLE = address(oracleProxy);
        ChainlinkOracle(ORACLE).initialize(deployer, eurUsdFeed, usdcUsdFeed, deployer);
        ChainlinkOracle(ORACLE).setDevMode(true);
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
        QuantillonVault(VAULT).setDevMode(true);
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
        HedgerPool(HEDGER_POOL).initialize(deployer, USDC, address(0), deployer, deployer, deployer, VAULT);
        HedgerPool(HEDGER_POOL).updateAddress(2, ORACLE);
        console2.log("HedgerPool deployed:", HEDGER_POOL);
        
        // Whitelist the deployer/hedger address immediately after deployment
        // The deployer has GOVERNANCE_ROLE from initialization, so can whitelist
        try HedgerPool(HEDGER_POOL).hedgerWhitelistEnabled() returns (bool whitelistEnabled) {
            if (whitelistEnabled) {
                HedgerPool(HEDGER_POOL).setHedgerWhitelist(deployer, true);
                console2.log("Hedger address whitelisted:", deployer);
            } else {
                console2.log("Hedger whitelist is disabled - no whitelisting needed");
            }
        } catch {
            console2.log("WARNING: Could not check whitelist status, attempting to whitelist anyway");
            try HedgerPool(HEDGER_POOL).setHedgerWhitelist(deployer, true) {
                console2.log("Hedger address whitelisted:", deployer);
            } catch {
                console2.log("WARNING: Could not whitelist hedger address");
            }
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

        // Read scenario mode from environment variable (default to "multiple" for backward compatibility)
        string memory mode;
        try vm.envString("SCENARIO_MODE") returns (string memory envMode) {
            mode = envMode;
        } catch {
            mode = "multiple";
        }
        useSinglePosition = keccak256(bytes(mode)) == keccak256(bytes("single"));

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

        console2.log("=== Starting Scenario Replay ===");
        console2.log("Using deployer account (PRIVATE_KEY from env)");
        console2.log(string.concat("Scenario mode: ", mode, " (", useSinglePosition ? "single position" : "multiple positions", ")"));
        if (stopAfterStep < 26) {
            console2.log(string.concat("Will stop after step: ", vm.toString(stopAfterStep)));
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
        _step1_HedgerDeposits50USDC();
        if (_shouldStop(1, stopAfterStep)) return;

        // Step 2: Oracle → 1.09
        _step2_SetOraclePrice(109 * 1e16); // 1.09
        if (_shouldStop(2, stopAfterStep)) return;

        // Step 3: User mints 500 QEURO
        _step3_UserMints500QEURO();
        if (_shouldStop(3, stopAfterStep)) return;

        // Step 4: Oracle → 1.11
        _step4_SetOraclePrice(111 * 1e16); // 1.11
        if (_shouldStop(4, stopAfterStep)) return;

        // Step 5: Hedger adds 50 USD to its position
        _step5_HedgerAdds50USDC();
        if (_shouldStop(5, stopAfterStep)) return;

        // Step 6: Oracle → 1.13
        _step6_SetOraclePrice(113 * 1e16); // 1.13
        if (_shouldStop(6, stopAfterStep)) return;

        // Step 7: User mints 350 QEURO
        _step7_UserMints350QEURO();
        if (_shouldStop(7, stopAfterStep)) return;

        // Step 8: Oracle → 1.15
        _step8_SetOraclePrice(115 * 1e16); // 1.15
        if (_shouldStop(8, stopAfterStep)) return;

        // Step 9: User redeems 180 QEURO
        _step9_UserRedeems180QEURO();
        if (_shouldStop(9, stopAfterStep)) return;

        // Step 10: Hedger deposits 50 more USD to its collateral
        _step10_HedgerAdds50USDC();
        if (_shouldStop(10, stopAfterStep)) return;

        // Step 11: User mints 500 QEURO
        _step11_UserMints500QEURO();
        if (_shouldStop(11, stopAfterStep)) return;

        // Step 12: Oracle → 1.12
        _step12_SetOraclePrice(112 * 1e16); // 1.12
        if (_shouldStop(12, stopAfterStep)) return;

        // Step 13: Oracle → 1.15
        _step13_SetOraclePrice(115 * 1e16); // 1.15
        if (_shouldStop(13, stopAfterStep)) return;

        // Step 14: Hedger adds 50 more USD to its collateral
        _step14_HedgerAdds50USDC();
        if (_shouldStop(14, stopAfterStep)) return;

        // Step 15: Oracle → 1.13
        _step15_SetOraclePrice(113 * 1e16); // 1.13
        if (_shouldStop(15, stopAfterStep)) return;

        // Step 16: Oracle → 1.11
        _step16_SetOraclePrice(111 * 1e16); // 1.11
        if (_shouldStop(16, stopAfterStep)) return;

        // Step 17: User mints 1500 QEURO
        _step17_UserMints1500QEURO();
        if (_shouldStop(17, stopAfterStep)) return;

        // Step 18: Oracle → 1.15
        _step18_SetOraclePrice(115 * 1e16); // 1.15
        if (_shouldStop(18, stopAfterStep)) return;

        // Step 19: User redeems 1000 QEURO
        _step19_UserRedeems1000QEURO();
        if (_shouldStop(19, stopAfterStep)) return;

        // Step 20: Oracle → 1.13
        _step20_SetOraclePrice(113 * 1e16); // 1.13
        if (_shouldStop(20, stopAfterStep)) return;

        // Step 21: User redeems 1000 QEURO
        _step21_UserRedeems1000QEURO();
        if (_shouldStop(21, stopAfterStep)) return;

        // Step 22: Hedger removes 50 USD from its collateral
        _step22_HedgerRemoves50USDC();
        if (_shouldStop(22, stopAfterStep)) return;

        // Step 23: Oracle → 1.16
        _step23_SetOraclePrice(116 * 1e16); // 1.16
        if (_shouldStop(23, stopAfterStep)) return;

        // Step 24: Hedger removes 20 USD from its collateral
        _step24_HedgerRemoves20USDC();
        if (_shouldStop(24, stopAfterStep)) return;

        // Step 25: Oracle → 1.10
        _step25_SetOraclePrice(110 * 1e16); // 1.10
        if (_shouldStop(25, stopAfterStep)) return;

        // Step 26: User redeems 670 QEURO
        _step26_UserRedeems670QEURO();
        if (_shouldStop(26, stopAfterStep)) return;

        vm.stopBroadcast();

        // Write deployed addresses to file for frontend
        _writeAddressesToFile();

        // Note: Statistics are logged to console, no need to save to file
        // (vm.writeFile is not allowed in broadcast mode)

        // Summary logged in _saveStatisticsToFile
    }

    /**
     * @notice Checks if scenario should stop after current step
     * @param currentStep Current step number (1-16)
     * @param stopAfterStep Step number to stop after (1-16)
     * @return shouldStop True if execution should stop
     */
    function _shouldStop(uint256 currentStep, uint256 stopAfterStep) internal returns (bool shouldStop) {
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
        console2.log("      \"MockEURUSD\": \"", vm.toString(MOCK_EUR_USD_FEED), "\",");
        console2.log("      \"ChainlinkOracle\": \"", vm.toString(ORACLE), "\",");
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
            qeuroShare: lastQeuroShare
        });
        
        // Reset qeuroShare after capturing stats
        lastQeuroShare = 0;

        stats.push(stat);

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
        UserPool userPool = UserPool(USER_POOL);
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        QuantillonVault vault = QuantillonVault(VAULT);

        (price, ) = oracle.getEurUsdPrice();
        qeuroMinted = qeuroToken.totalSupply();
        userCollateral = userPool.totalUserDeposits();
        hedgerCollateral = hedgerPool.totalMargin();
        uint256 collateralizationRatio = vault.getProtocolCollateralizationRatio();
        // Store as 18 decimals (e.g., 109183495000000000000 = 109.183495%) for maximum precision
        collateralizationPercentage = collateralizationRatio;
        
        // Get FeeCollector USDC balance (protocol treasury)
        if (FEE_COLLECTOR != address(0)) {
            IERC20 usdcToken = IERC20(USDC);
            protocolTreasury = usdcToken.balanceOf(FEE_COLLECTOR);
        } else {
            protocolTreasury = 0;
        }
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
        
        // Initialize aggregated values
        hedgerEntryPrice = 0;
        hedgerRealizedPnL = int256(0);
        hedgerUnrealizedPnL = int256(0);
        hedgerTotalPnL = int256(0);
        hedgerAvailableCollateral = 0;
        hedgerMaxWithdrawable = 0;
        qeuroMintable = 0;
        
        // Get nextPositionId to know the upper limit
        uint256 nextPositionId = hedgerPool.nextPositionId();
            
        // Get core parameters (same for all positions)
        (uint64 minMarginRatio, uint64 liquidationThreshold, , , , , , , , ) = hedgerPool.coreParams();
        
        // Get total supply once (used for all positions)
        QEUROToken qeuroToken = QEUROToken(QEURO);
        uint256 totalSupply = qeuroToken.totalSupply();
            
        // Variables for weighted average entry price calculation
        uint256 totalWeightedEntryPrice = 0;
        uint256 totalFilledVolume = 0;
        
        // Variables for aggregated margin calculations
        int256 totalEffectiveMargin = 0;
        uint256 totalRequiredMargin = 0;
        uint256 totalMinimumMargin = 0;
        
        // Iterate through all positions to find hedger's active positions
        for (uint256 positionId = 1; positionId < nextPositionId; positionId++) {
            (address positionHedger, , uint96 filledVolume, uint96 margin, uint96 entryPrice, , , , int128 realizedPnLFromContract, , bool isActive, uint128 qeuroBacked) = hedgerPool.positions(positionId);
            
            // Skip if not owned by hedger or not active
            if (positionHedger != hedger || !isActive) {
                continue;
            }
            
            // Sum realized P&L
            hedgerRealizedPnL += int256(realizedPnLFromContract);
            
            // Calculate unrealized P&L for this position
            // NOTE: This matches the contract's HedgerPoolLogicLibrary.calculatePnL formula exactly
            // Formula: UnrealizedP&L = FilledVolume - QEUROBacked * OracleCurrentPrice
            // The contract uses gross filledVolume (fee is paid by buyer, not hedger)
            int256 totalUnrealizedPnL;
            if (totalSupply == 0 || filledVolume == 0 || price == 0 || qeuroBacked == 0) {
                totalUnrealizedPnL = int256(0);
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
            
            // Calculate net unrealized P&L (matching original logic)
            int256 positionUnrealizedPnL;
            if (totalSupply == 0 || qeuroBacked == 0) {
                positionUnrealizedPnL = int256(0);
            } else {
                positionUnrealizedPnL = totalUnrealizedPnL - int256(realizedPnLFromContract);
            }
            
            hedgerUnrealizedPnL += positionUnrealizedPnL;
            
            // Calculate effective margin for this position
            int256 effectiveMargin = int256(uint256(margin)) + positionUnrealizedPnL + int256(realizedPnLFromContract);
            
            // Sum effective margins across all positions
            totalEffectiveMargin += effectiveMargin;
            
            // Calculate required margin for this position
            uint256 mintedExposure = (uint256(qeuroBacked) * price) / 1e30;
            uint256 hedgerRequiredMargin = (mintedExposure * uint256(minMarginRatio)) / 10000;
            totalRequiredMargin += hedgerRequiredMargin;
            
            // Calculate minimum margin (for max withdrawable) for this position
            if (uint256(qeuroBacked) > 0 && price > 0 && liquidationThreshold > 0) {
                uint256 minimumMargin = (mintedExposure * uint256(liquidationThreshold)) / 10000;
                totalMinimumMargin += minimumMargin;
            }
            
            // For weighted average entry price, use filled volume as weight
            if (filledVolume > 0) {
                totalWeightedEntryPrice += uint256(entryPrice) * uint256(filledVolume);
                totalFilledVolume += uint256(filledVolume);
            }
        }
        
        // Calculate weighted average entry price
        if (totalFilledVolume > 0) {
            hedgerEntryPrice = totalWeightedEntryPrice / totalFilledVolume;
        }
        
        // Calculate aggregated available collateral: total effective margin - total required margin
        if (totalEffectiveMargin > int256(totalRequiredMargin)) {
            hedgerAvailableCollateral = uint256(totalEffectiveMargin) - totalRequiredMargin;
        }
        
        // Calculate aggregated max withdrawable: total effective margin - total minimum margin
        if (totalEffectiveMargin > int256(totalMinimumMargin)) {
            hedgerMaxWithdrawable = uint256(totalEffectiveMargin) - totalMinimumMargin;
        } else if (totalEffectiveMargin > 0) {
            hedgerMaxWithdrawable = uint256(totalEffectiveMargin);
            }
        
        // Calculate total P&L
        hedgerTotalPnL = hedgerUnrealizedPnL + hedgerRealizedPnL;
            
        // Calculate QEURO mintable from total available collateral
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
        console2.log("");
    }

    function _step1_HedgerDeposits50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        console2.log("--- Step 1: Opening Hedger Position ---");
        console2.log("Creating position for hedger address:", hedger);
        console2.log("NOTE: Connect your wallet to this address in the UI to see the position!");

        // Check if whitelist is enabled and whitelist hedger if needed
        // The deployer should have GOVERNANCE_ROLE to whitelist
        // Wrap in try-catch to handle cases where contract may not be deployed
        try HedgerPool(HEDGER_POOL).hedgerWhitelistEnabled() returns (bool whitelistEnabled) {
            if (whitelistEnabled) {
                try HedgerPool(HEDGER_POOL).isWhitelistedHedger(hedger) returns (bool isWhitelisted) {
                    if (!isWhitelisted) {
                        console2.log("Whitelisting hedger:", hedger);
                        hedgerPool.setHedgerWhitelist(hedger, true);
                    } else {
                        console2.log("Hedger already whitelisted:", hedger);
                    }
                } catch {
                    console2.log("WARNING: Could not check hedger whitelist status");
                }
            }
        } catch {
            console2.log("WARNING: Could not check if whitelist is enabled, skipping whitelist check");
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
        
        // Get current price from oracle
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Oracle price invalid");
        
        // If already at target, just update cache and return
        if (currentPrice == targetPrice) {
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
        
        if (useSinglePosition) {
            // Add margin to existing position (position ID 1 from step 1)
            console2.log("--- Step 5: Adding Margin to Existing Position ---");
            console2.log("Adding 50 USDC to position ID 1 for hedger address:", hedger);
            
            try hedgerPool.addMargin(1, amount) {
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
        } else {
            // Open new position with 5% margin (20x leverage)
            console2.log("--- Step 5: Opening New Hedger Position ---");
            console2.log("Opening second position for hedger address:", hedger);
            uint256 leverage = 20; // 5% margin = 20x leverage
            console2.log(string.concat("Opening new position with leverage: ", vm.toString(leverage), "x"));
            
            try hedgerPool.enterHedgePosition(amount, leverage) returns (uint256 positionId) {
                latestPositionId = positionId;
                console2.log(string.concat("New position opened successfully! Position ID: ", vm.toString(positionId)));
            } catch Error(string memory reason) {
                console2.log("ERROR: Failed to open new hedger position:", reason);
                revert(string.concat("Step 5 failed: ", reason));
            } catch (bytes memory) {
                console2.log("ERROR: Failed to open new hedger position (low-level error)");
                revert("Step 5 failed: HedgerPool contract call reverted");
            }
            console2.log("");
            _captureStats("Hedger opens new position with 50 USDC");
        }
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
        
        // Listen for QeuroShareCalculated events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0); // minUsdcOut = 0
        
        // Check for QeuroShareCalculated events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            bytes32 eventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == eventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                    break;
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
        
        if (useSinglePosition) {
            // Add margin to existing position (position ID 1 from step 1)
            console2.log("--- Step 10: Adding Margin to Existing Position ---");
            console2.log("Adding 50 USDC to position ID 1 for hedger address:", hedger);
            
            try hedgerPool.addMargin(1, amount) {
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
        } else {
            // Open new position with 5% margin (20x leverage)
            console2.log("--- Step 10: Opening New Hedger Position ---");
            console2.log("Opening new position for hedger address:", hedger);
            uint256 leverage = 20; // 5% margin = 20x leverage
            console2.log(string.concat("Opening new position with leverage: ", vm.toString(leverage), "x"));
            
            try hedgerPool.enterHedgePosition(amount, leverage) returns (uint256 positionId) {
                latestPositionId = positionId;
                console2.log(string.concat("New position opened successfully! Position ID: ", vm.toString(positionId)));
            } catch Error(string memory reason) {
                console2.log("ERROR: Failed to open new hedger position:", reason);
                revert(string.concat("Step 10 failed: ", reason));
            } catch (bytes memory) {
                console2.log("ERROR: Failed to open new hedger position (low-level error)");
                revert("Step 10 failed: HedgerPool contract call reverted");
            }
            console2.log("");
            _captureStats("Hedger opens new position with 50 USDC");
        }
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
        
        if (useSinglePosition) {
            // Add margin to existing position (position ID 1 from step 1)
            console2.log("--- Step 14: Adding Margin to Existing Position ---");
            console2.log("Adding 50 USDC to position ID 1 for hedger address:", hedger);
            
            try hedgerPool.addMargin(1, amount) {
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
        } else {
            // Open new position with 5% margin (20x leverage)
            console2.log("--- Step 14: Opening New Hedger Position ---");
            console2.log("Opening new position for hedger address:", hedger);
            uint256 leverage = 20; // 5% margin = 20x leverage
            console2.log(string.concat("Opening new position with leverage: ", vm.toString(leverage), "x"));
            
            try hedgerPool.enterHedgePosition(amount, leverage) returns (uint256 positionId) {
                latestPositionId = positionId;
                console2.log(string.concat("New position opened successfully! Position ID: ", vm.toString(positionId)));
            } catch Error(string memory reason) {
                console2.log("ERROR: Failed to open new hedger position:", reason);
                revert(string.concat("Step 14 failed: ", reason));
            } catch (bytes memory) {
                console2.log("ERROR: Failed to open new hedger position (low-level error)");
                revert("Step 14 failed: HedgerPool contract call reverted");
            }
            console2.log("");
            _captureStats("Hedger opens new position with 50 USDC");
        }
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
        
        // Listen for QeuroShareCalculated events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0);
        
        // Check for QeuroShareCalculated events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            bytes32 eventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == eventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                    break;
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
        
        // Listen for QeuroShareCalculated events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0);
        
        // Check for QeuroShareCalculated events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            bytes32 eventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == eventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                    break;
                }
            }
        }

        _captureStats("User redeems 1000 QEURO");
    }

    function _step22_HedgerRemoves50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);

        uint256 totalAmountToRemove = 50 * 1e6; // 50 USDC
        uint256 nextPositionId = hedgerPool.nextPositionId();
        
        console2.log("--- Step 22: Removing Margin from Positions ---");
        console2.log("Target: Remove 50 USDC total, spreading across available positions");
        
        uint256 remainingToRemove = totalAmountToRemove;
        
        // Get current price and core parameters for upfront calculations
        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        (, uint64 liquidationThreshold, , , , , , , , ) = hedgerPool.coreParams();
        
        // Iterate through positions and calculate maximum removable amount upfront
        for (uint256 id = 1; id < nextPositionId && remainingToRemove > 0; id++) {
            (address positionHedger, , uint96 filledVolume, uint96 margin, , , , , , uint16 leverage, bool isActive, uint128 qeuroBacked) = hedgerPool.positions(id);
            
            // Skip if not owned by hedger or not active
            if (positionHedger != hedger || !isActive) {
                continue;
            }
            
            // Calculate maximum removable amount considering all constraints
            uint256 maxRemovable = 0;
            
            if (uint256(filledVolume) == 0) {
                // No exposure, can remove all margin
                maxRemovable = uint256(margin);
            } else {
                // Constraint 1: Capacity - newPositionSize >= filledVolume
                // newPositionSize = (margin - removeAmount) * leverage
                // So: (margin - removeAmount) * leverage >= filledVolume
                // removeAmount <= margin - (filledVolume / leverage)
                uint256 minMarginForCapacity = (uint256(filledVolume) + uint256(leverage) - 1) / uint256(leverage);
                uint256 maxRemovableForCapacity = uint256(margin) > minMarginForCapacity 
                    ? uint256(margin) - minMarginForCapacity 
                    : 0;
                
                // Constraint 2: Margin ratio - newMarginRatio >= minMarginRatio
                // newMarginRatio = newMargin / newPositionSize * 10000
                // newMargin = margin - removeAmount, newPositionSize = newMargin * leverage
                // So: (margin - removeAmount) / ((margin - removeAmount) * leverage) * 10000 >= minMarginRatio
                // This simplifies to: 10000 / leverage >= minMarginRatio
                // Since leverage is fixed, this constraint is always satisfied if the position was valid
                // So we don't need to check this separately
                
                // Constraint 3: Liquidation - position must not be liquidatable after margin removal
                // The contract uses: marginRatio = effectiveMargin * 10000 / qeuroValueInUSDC
                // Position is liquidatable if marginRatio < liquidationThreshold
                // effectiveMargin = newMargin + calculatePnL(filledVolume, qeuroBacked, currentPrice)
                // Note: calculatePnL recalculates P&L, doesn't use stored unrealizedPnL
                
                // Calculate qeuroValueInUSDC for margin ratio calculation
                uint256 qeuroValueInUSDC = (uint256(qeuroBacked) * currentPrice) / 1e30;
                
                // Recalculate P&L using same formula as contract
                int256 pnl = 0;
                if (filledVolume > 0 && currentPrice > 0 && qeuroBacked > 0) {
                    if (uint256(filledVolume) >= qeuroValueInUSDC) {
                        pnl = int256(uint256(filledVolume) - qeuroValueInUSDC);
                    } else {
                        pnl = -int256(qeuroValueInUSDC - uint256(filledVolume));
                    }
                }
                
                // Calculate maximum removable amount for liquidation constraint
                uint256 maxRemovableForLiquidation = 0;
                
                if (qeuroValueInUSDC == 0) {
                    // No exposure, can remove all margin
                    maxRemovableForLiquidation = uint256(margin);
                } else {
                    // We need: (newMargin + pnl) * 10000 / qeuroValueInUSDC >= liquidationThreshold
                    // So: newMargin + pnl >= qeuroValueInUSDC * liquidationThreshold / 10000
                    // newMargin >= (qeuroValueInUSDC * liquidationThreshold / 10000) - pnl
                    uint256 requiredEffectiveMargin = (qeuroValueInUSDC * uint256(liquidationThreshold)) / 10000;
                    int256 requiredMargin = int256(requiredEffectiveMargin) - pnl;
                    
                    uint256 minMarginForLiquidation = 0;
                    if (requiredMargin > 0) {
                        minMarginForLiquidation = uint256(requiredMargin);
                    }
                    
                    // Add small safety margin (1%) to avoid edge cases
                    minMarginForLiquidation = minMarginForLiquidation * 101 / 100;
                    
                    maxRemovableForLiquidation = uint256(margin) > minMarginForLiquidation 
                        ? uint256(margin) - minMarginForLiquidation 
                        : 0;
                }
                
                // Take the minimum of all constraints
                maxRemovable = maxRemovableForCapacity < maxRemovableForLiquidation 
                    ? maxRemovableForCapacity 
                    : maxRemovableForLiquidation;
            }
            
            // Remove the calculated amount (or remaining amount, whichever is smaller)
            if (maxRemovable > 0) {
                uint256 amountToRemove = maxRemovable < remainingToRemove ? maxRemovable : remainingToRemove;
                
                // Use expectRevert to suppress failed attempt traces
                // First check if it will succeed by trying without expecting revert
                bool success = false;
                try hedgerPool.removeMargin(id, amountToRemove) {
                    console2.log(string.concat("Removed ", vm.toString(amountToRemove / 1e6), " USDC from position ID: ", vm.toString(id)));
                    remainingToRemove -= amountToRemove;
                    success = true;
                } catch {
                    // Suppress the trace by not logging the failure
                    // Try with a small reduction (2% safety margin)
                    if (amountToRemove > 2e6) {
                        amountToRemove = amountToRemove * 98 / 100;
                        try hedgerPool.removeMargin(id, amountToRemove) {
                            console2.log(string.concat("Removed ", vm.toString(amountToRemove / 1e6), " USDC from position ID: ", vm.toString(id)));
                            remainingToRemove -= amountToRemove;
                            success = true;
                        } catch {
                            // Skip silently - calculation was off, position can't have margin removed
                        }
                    }
                }
            }
        }
        
        if (remainingToRemove > 0) {
            console2.log(string.concat("WARNING: Could only remove ", vm.toString((totalAmountToRemove - remainingToRemove) / 1e6), " USDC out of ", vm.toString(totalAmountToRemove / 1e6), " USDC requested"));
            console2.log(string.concat("Remaining: ", vm.toString(remainingToRemove / 1e6), " USDC could not be removed"));
        } else {
            console2.log("Successfully removed 50 USDC total across positions");
        }

        _captureStats("Hedger removes 50 USDC from collateral");
    }

    function _step23_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.16");
    }

    function _step24_HedgerRemoves20USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);

        uint256 totalAmountToRemove = 20 * 1e6; // 20 USDC
        uint256 nextPositionId = hedgerPool.nextPositionId();
        
        console2.log("--- Step 24: Removing Margin from Positions ---");
        console2.log("Target: Remove 20 USDC total, spreading across available positions");
        
        uint256 remainingToRemove = totalAmountToRemove;
        
        // Get current price and core parameters for upfront calculations
        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        (, uint64 liquidationThreshold, , , , , , , , ) = hedgerPool.coreParams();
        
        // Iterate through positions and calculate maximum removable amount upfront
        for (uint256 id = 1; id < nextPositionId && remainingToRemove > 0; id++) {
            (address positionHedger, , uint96 filledVolume, uint96 margin, , , , , , uint16 leverage, bool isActive, uint128 qeuroBacked) = hedgerPool.positions(id);
            
            // Skip if not owned by hedger or not active
            if (positionHedger != hedger || !isActive) {
                continue;
            }
            
            // Calculate maximum removable amount considering all constraints
            uint256 maxRemovable = 0;
            
            if (uint256(filledVolume) == 0) {
                // No exposure, can remove all margin
                maxRemovable = uint256(margin);
            } else {
                // Constraint 1: Capacity - newPositionSize >= filledVolume
                uint256 minMarginForCapacity = (uint256(filledVolume) + uint256(leverage) - 1) / uint256(leverage);
                uint256 maxRemovableForCapacity = uint256(margin) > minMarginForCapacity 
                    ? uint256(margin) - minMarginForCapacity 
                    : 0;
                
                // Constraint 3: Liquidation - position must not be liquidatable after margin removal
                uint256 qeuroValueInUSDC = (uint256(qeuroBacked) * currentPrice) / 1e30;
                
                // Recalculate P&L using same formula as contract
                int256 pnl = 0;
                if (filledVolume > 0 && currentPrice > 0 && qeuroBacked > 0) {
                    if (uint256(filledVolume) >= qeuroValueInUSDC) {
                        pnl = int256(uint256(filledVolume) - qeuroValueInUSDC);
                    } else {
                        pnl = -int256(qeuroValueInUSDC - uint256(filledVolume));
                    }
                }
                
                // Calculate maximum removable amount for liquidation constraint
                uint256 maxRemovableForLiquidation = 0;
                
                if (qeuroValueInUSDC == 0) {
                    // No exposure, can remove all margin
                    maxRemovableForLiquidation = uint256(margin);
                } else {
                    uint256 requiredEffectiveMargin = (qeuroValueInUSDC * uint256(liquidationThreshold)) / 10000;
                    int256 requiredMargin = int256(requiredEffectiveMargin) - pnl;
                    
                    uint256 minMarginForLiquidation = 0;
                    if (requiredMargin > 0) {
                        minMarginForLiquidation = uint256(requiredMargin);
                    }
                    
                    // Add small safety margin (1%) to avoid edge cases
                    minMarginForLiquidation = minMarginForLiquidation * 101 / 100;
                    
                    maxRemovableForLiquidation = uint256(margin) > minMarginForLiquidation 
                        ? uint256(margin) - minMarginForLiquidation 
                        : 0;
                }
                
                // Take the minimum of all constraints
                maxRemovable = maxRemovableForCapacity < maxRemovableForLiquidation 
                    ? maxRemovableForCapacity 
                    : maxRemovableForLiquidation;
            }
            
            // Remove the calculated amount (or remaining amount, whichever is smaller)
            if (maxRemovable > 0) {
                uint256 amountToRemove = maxRemovable < remainingToRemove ? maxRemovable : remainingToRemove;
                
                // Use expectRevert to suppress failed attempt traces
                bool success = false;
                try hedgerPool.removeMargin(id, amountToRemove) {
                    console2.log(string.concat("Removed ", vm.toString(amountToRemove / 1e6), " USDC from position ID: ", vm.toString(id)));
                    remainingToRemove -= amountToRemove;
                    success = true;
                } catch {
                    // Suppress the trace by not logging the failure
                    // Try with a small reduction (2% safety margin)
                    if (amountToRemove > 2e6) {
                        amountToRemove = amountToRemove * 98 / 100;
                        try hedgerPool.removeMargin(id, amountToRemove) {
                            console2.log(string.concat("Removed ", vm.toString(amountToRemove / 1e6), " USDC from position ID: ", vm.toString(id)));
                            remainingToRemove -= amountToRemove;
                            success = true;
                        } catch {
                            // Skip silently - calculation was off, position can't have margin removed
                        }
                    }
                }
            }
        }
        
        if (remainingToRemove > 0) {
            console2.log(string.concat("WARNING: Could only remove ", vm.toString((totalAmountToRemove - remainingToRemove) / 1e6), " USDC out of ", vm.toString(totalAmountToRemove / 1e6), " USDC requested"));
            console2.log(string.concat("Remaining: ", vm.toString(remainingToRemove / 1e6), " USDC could not be removed"));
        } else {
            console2.log("Successfully removed 20 USDC total across positions");
        }

        _captureStats("Hedger removes 20 USD from its collateral");
    }

    function _step25_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.10");
    }

    function _step26_UserRedeems670QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 670 * 1e18;
        qeuroToken.approve(VAULT, qeuroAmount);
        
        // Listen for QeuroShareCalculated events
        vm.recordLogs();
        vault.redeemQEURO(qeuroAmount, 0);
        
        // Check for QeuroShareCalculated events
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            bytes32 eventSig = keccak256("QeuroShareCalculated(uint256,uint256,uint256,uint256)");
            if (logs[i].topics.length >= 2 && logs[i].topics[0] == eventSig) {
                if (uint256(logs[i].topics[1]) == positionId) {
                    (uint256 qeuroShare, , ) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                    lastQeuroShare = qeuroShare;
                    break;
                }
            }
        }

        _captureStats("User redeems 670 QEURO");
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

