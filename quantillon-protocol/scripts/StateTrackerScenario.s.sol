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
 *   - Opens a hedger position with initial collateral
 *   - Position size = 50 USDC * 20 = 1000 USDC capacity
 * 
 * Step 2: Oracle price → 1.09 USD/EUR
 *   - Updates the EUR/USD exchange rate
 * 
 * Step 3: User mints 500 QEURO
 *   - User deposits USDC to mint QEURO at current oracle price (1.09)
 *   - Hedger position gets filled proportionally
 * 
 * Step 4: Oracle price → 1.16 USD/EUR
 *   - Significant price increase (EUR appreciates)
 * 
 * Step 5: Hedger opens new position with 50 USDC
 *   - Hedger opens a second position with 50 USDC at 5% margin (20x leverage)
 *   - Creates a new separate position instead of adding to existing one
 * 
 * Step 6: User mints 500 QEURO
 *   - Additional QEURO minting at higher price (1.16)
 *   - More hedger capacity gets utilized
 * 
 * Step 7: Hedger opens new position with 50 USDC
 *   - Hedger opens a third position with 50 USDC at 5% margin (20x leverage)
 *   - Creates another separate position
 *   - Total hedger margin now: 150 USDC across 3 positions
 * 
 * Step 8: Oracle price → 1.11 USD/EUR
 *   - Price correction (EUR depreciates from 1.16)
 * 
 * Step 9: User mints 861 QEURO
 *   - Large mint operation at 1.11 price
 * 
 * Step 10: User mints 1000 QEURO
 *   - Additional large mint
 *   - Total QEURO supply peaks at this point
 * 
 * Step 11: User redeems 1861 QEURO
 *   - Large redemption operation
 *   - Tests hedger position unwinding and realized P&L
 * 
 * Step 12: Oracle price → 1.15 USD/EUR
 *   - Price increase after redemption
 * 
 * Step 13: Hedger removes 50 USDC from collateral
 *   - Hedger withdraws margin from latest position
 *   - Position size decreases proportionally
 * 
 * Step 14: Oracle price → 1.16 USD/EUR
 *   - Price increase to match earlier high
 * 
 * Step 15: User redeems 500 QEURO
 *   - Redemption operation
 *
 * Step 16: User redeems 500 QEURO (no QEURO left circulating)
 *   - Final redemption operation
 *   - Tests protocol state with zero QEURO supply
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

    // Test accounts
    address public hedger;
    address public user;

    // Scenario step counter
    uint256 public stepCounter = 0;
    
    // Track latest position ID opened by hedger
    uint256 public latestPositionId = 0;

    struct ProtocolStats {
        uint256 step;
        string action;
        // Protocol statistics
        uint256 oraclePrice; // 18 decimals
        uint256 qeuroMinted; // 18 decimals (totalSupply)
        uint256 qeuroMintable; // 18 decimals (calculated)
        uint256 userCollateral; // 6 decimals (user deposits)
        uint256 hedgerCollateral; // 6 decimals (hedger margin)
        uint256 collateralizationPercentage; // percentage (collateralizationRatio / 100)
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
    function _deployContracts() internal {
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
        
        // Deploy QEURO
        QEUROToken qeuroImpl = new QEUROToken();
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImpl), bytes(""));
        QEURO = address(qeuroProxy);
        QEUROToken(QEURO).initialize(deployer, deployer, deployer, deployer);
        console2.log("QEURO deployed:", QEURO);
        
        // Deploy FeeCollector
        address treasury = address(uint160(uint256(keccak256(abi.encodePacked("treasury", deployer)))));
        address devFund = address(uint160(uint256(keccak256(abi.encodePacked("devFund", deployer)))));
        address communityFund = address(uint160(uint256(keccak256(abi.encodePacked("communityFund", deployer)))));
        
        FeeCollector feeCollectorImpl = new FeeCollector();
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), bytes(""));
        address feeCollector = address(feeCollectorProxy);
        FeeCollector(feeCollector).initialize(deployer, treasury, devFund, communityFund);
        console2.log("FeeCollector deployed:", feeCollector);
        
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
        try this._safeIsWhitelistEnabled(HEDGER_POOL) returns (bool whitelistEnabled) {
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

    function run() external {
        // Use deployer's private key (same as deployment scripts)
        // This ensures the hedger position is visible in the UI when connected with the same account
        uint256 pk = vm.envUint("PRIVATE_KEY");
        hedger = vm.addr(pk);
        user = vm.addr(pk); // Using same account for simplicity (deployer account)

        console2.log("=== Starting Scenario Replay ===");
        console2.log("Using deployer account (PRIVATE_KEY from env)");
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
        _deployContracts();

        // Verify protocol is in fresh state (non-fatal - continue even if checks fail)
        console2.log("--- Verifying Fresh State ---");
        uint256 initialSupply = 0;
        uint256 initialMargin = 0;
        uint256 initialExposure = 0;
        
        // Check QEURO totalSupply with comprehensive error handling
        try this._safeGetTotalSupply(QEURO) returns (uint256 supply) {
            initialSupply = supply;
            console2.log("Initial QEURO Supply:", initialSupply / 1e18);
        } catch Error(string memory) {
            console2.log("WARNING: Could not read QEURO totalSupply (revert with reason)");
        } catch (bytes memory) {
            console2.log("WARNING: Could not read QEURO totalSupply (low-level error)");
        }
        
        // Check HedgerPool totalMargin with comprehensive error handling
        try this._safeGetTotalMargin(HEDGER_POOL) returns (uint256 margin) {
            initialMargin = margin;
            console2.log("Initial Hedger Margin:", initialMargin / 1e6);
        } catch Error(string memory) {
            console2.log("WARNING: Could not read HedgerPool totalMargin (revert with reason)");
        } catch (bytes memory) {
            console2.log("WARNING: Could not read HedgerPool totalMargin (low-level error)");
        }
        
        // Check HedgerPool totalExposure with comprehensive error handling
        try this._safeGetTotalExposure(HEDGER_POOL) returns (uint256 exposure) {
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
        // Step 1: Hedger deposits 50 USDC at 5% margin
        _step1_HedgerDeposits50USDC();

        // Step 2: Oracle → 1.09
        _step2_SetOraclePrice(109 * 1e16); // 1.09

        // Step 3: User mints 500 QEURO
        _step3_UserMints500QEURO();

        // Step 4: Oracle → 1.16
        _step4_SetOraclePrice(116 * 1e16); // 1.16

        // Step 5: Hedger adds 50 USDC
        _step5_HedgerAdds50USDC();

        // Step 6: User mints 500 QEURO
        _step6_UserMints500QEURO();

        // Step 7: Hedger adds 50 USDC
        _step7_HedgerAdds50USDC();

        // Step 8: Oracle → 1.11
        _step8_SetOraclePrice(111 * 1e16); // 1.11

        // Step 9: User mints 861 QEURO
        _step9_UserMints861QEURO();

        // Step 10: User mints 1000 QEURO
        _step10_UserMints1000QEURO();

        // Step 11: User redeems 1861 QEURO
        _step11_UserRedeems1861QEURO();

        // Step 12: Oracle → 1.15
        _step12_SetOraclePrice(115 * 1e16); // 1.15

        // Step 13: Hedger removes 50 USDC from collateral
        _step13_HedgerRemoves50USDC();

        // Step 14: Oracle → 1.16
        _step14_SetOraclePrice(116 * 1e16); // 1.16

        // Step 15: User redeems 500 QEURO
        _step15_UserRedeems500QEURO();

        // Step 16: User redeems 500 QEURO (no QEURO left circulating)
        _step16_UserRedeems500QEURO();

        vm.stopBroadcast();

        // Write deployed addresses to file for frontend
        _writeAddressesToFile();

        // Note: Statistics are logged to console, no need to save to file
        // (vm.writeFile is not allowed in broadcast mode)

        // Summary logged in _saveStatisticsToFile
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

    // Helper functions for safe contract calls (must be external for try-catch)
    function _safeGetTotalSupply(address token) external view returns (uint256) {
        return QEUROToken(token).totalSupply();
    }

    function _safeGetTotalMargin(address hedgerPool) external view returns (uint256) {
        return HedgerPool(hedgerPool).totalMargin();
    }

    function _safeGetTotalExposure(address hedgerPool) external view returns (uint256) {
        return HedgerPool(hedgerPool).totalExposure();
    }

    function _safeIsWhitelistEnabled(address hedgerPool) external view returns (bool) {
        return HedgerPool(hedgerPool).hedgerWhitelistEnabled();
    }

    function _safeIsWhitelistedHedger(address hedgerPool, address hedgerAddr) external view returns (bool) {
        return HedgerPool(hedgerPool).isWhitelistedHedger(hedgerAddr);
    }

    uint256 lastQeuroShare; // Track last qeuroShare from redemption events

    function _captureStats(string memory action) internal {
        stepCounter++;
        
        // Get basic protocol stats
        (uint256 price, uint256 qeuroMinted, uint256 userCollateral, uint256 hedgerCollateral, uint256 collateralizationPercentage) = _getProtocolStats();
        
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
        uint256 collateralizationPercentage
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
        // Store as basis points (e.g., 11120 bps = 111.20%) for 2 decimal precision
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
            
            // Calculate unrealized P&L for this position (matching original logic)
            
            int256 totalUnrealizedPnL;
            if (totalSupply == 0 || filledVolume == 0 || price == 0 || qeuroBacked == 0) {
                totalUnrealizedPnL = int256(0);
            } else {
                uint256 qeuroValueInUSDC = (uint256(qeuroBacked) * price) / 1e30;
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
        // P&L is in 6 decimals (USDC), format to 2 decimals
        // Example: 975700000 (6 decimals) = 975.70 USDC
        // wholePart = 975700000 / 1e6 = 975
        // decimalPart = (975700000 / 1e4) % 100 = 97570 % 100 = 70
        bool isNegative = pnl < 0;
        uint256 absPnl = isNegative ? uint256(-pnl) : uint256(pnl);
        
        uint256 wholePart = absPnl / 1e6; // Get whole part (divide by 1e6 to get integer part)
        uint256 decimalPart = (absPnl / 1e4) % 100; // Get 2 decimal places (divide by 1e4, then mod 100)
        
        string memory sign = isNegative ? "-" : "";
        string memory result = string.concat(
            sign,
            vm.toString(wholePart),
            ".",
            decimalPart < 10 ? "0" : "",
            vm.toString(decimalPart)
        );
        return result;
    }

    function _formatPnLForFile(int256 pnl) internal pure returns (string memory) {
        // Same as _formatPnL but for file output
        return _formatPnL(pnl);
    }

    function _formatUSDC(uint256 usdcAmount) internal pure returns (string memory) {
        // USDC is in 6 decimals, format to 2 decimals
        // Example: 50000000 (6 decimals) = 50.00 USDC
        // wholePart = 50000000 / 1e6 = 50
        // decimalPart = (50000000 / 1e4) % 100 = 5000 % 100 = 0
        uint256 wholePart = usdcAmount / 1e6; // Get whole part (divide by 1e6 to get integer part)
        uint256 decimalPart = (usdcAmount / 1e4) % 100; // Get 2 decimal places (divide by 1e4, then mod 100)
        
        return string.concat(
            vm.toString(wholePart),
            ".",
            decimalPart < 10 ? "0" : "",
            vm.toString(decimalPart)
        );
    }

    function _formatQEURO(uint256 qeuroAmount) internal pure returns (string memory) {
        // QEURO is in 18 decimals, format to 2 decimals
        // Example: 197297290000000000000000 (18 decimals) = 197297.29 QEURO
        // wholePart = 197297290000000000000000 / 1e18 = 197297
        // scaledAmount = 197297290000000000000000 / 1e16 = 19729729
        // decimalPart = 19729729 % 100 = 29
        uint256 wholePart = qeuroAmount / 1e18; // Get whole part (divide by 1e18 to get integer)
        uint256 scaledAmount = qeuroAmount / 1e16; // Scale down by 1e16 to get price * 100
        uint256 decimalPart = scaledAmount % 100; // Get last 2 digits (the decimal part * 100)
        
        return string.concat(
            vm.toString(wholePart),
            ".",
            decimalPart < 10 ? "0" : "",
            vm.toString(decimalPart)
        );
    }

    function _formatPrice(uint256 price) internal pure returns (string memory) {
        // Price is in 18 decimals (e.g., 1.09e18 = 1090000000000000000), format to 2 decimals (e.g., "1.09")
        // wholePart = 1090000000000000000 / 1e18 = 1
        // decimalPart = (1090000000000000000 / 1e16) % 100 = 109 % 100 = 9, but we want 09
        // Actually: decimalPart = (price / 1e16) % 100 gives us the last 2 digits of the price scaled by 1e16
        // For 1.09: price = 1090000000000000000, (price / 1e16) = 109, % 100 = 9
        // We need: (price / 1e16) % 100, but if it's < 10, pad with 0
        
        // Actually simpler: divide by 1e18 to get integer part, then multiply by 100 and mod 100 for decimals
        uint256 wholePart = price / 1e18; // Get whole part (divide by 1e18 to get integer)
        uint256 scaledPrice = price / 1e16; // Scale down by 1e16 to get price * 100
        uint256 decimalPart = scaledPrice % 100; // Get last 2 digits (the decimal part * 100)
        
        return string.concat(
            vm.toString(wholePart),
            ".",
            decimalPart < 10 ? "0" : "",
            vm.toString(decimalPart)
        );
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
        // Format as percentage with 2 decimals (e.g., 11120 bps = 111.20%)
        uint256 wholePart = stat.collateralizationPercentage / 100;
        uint256 decimalPart = stat.collateralizationPercentage % 100;
        string memory collatPct = string.concat(
            vm.toString(wholePart),
            ".",
            decimalPart < 10 ? "0" : "",
            vm.toString(decimalPart),
            "%"
        );
        console2.log("  Collateralization Percentage:", collatPct);
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
        try this._safeIsWhitelistEnabled(HEDGER_POOL) returns (bool whitelistEnabled) {
            if (whitelistEnabled) {
                try this._safeIsWhitelistedHedger(HEDGER_POOL, hedger) returns (bool isWhitelisted) {
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

    function _step3_UserMints500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        // Calculate USDC needed for 500 QEURO at current price
        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        // 500 QEURO * price / 1e12 (convert from 18 to 6 decimals)
        uint256 usdcNeeded = (500 * 1e18 * currentPrice) / 1e30;
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0); // minQeuroOut = 0 for simplicity

        _captureStats("User mints 500 QEURO");
    }

    function _step4_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.16");
    }

    function _step5_HedgerAdds50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        console2.log("--- Step 5: Opening New Hedger Position ---");
        console2.log("Opening second position for hedger address:", hedger);

        uint256 amount = 50 * 1e6; // 50 USDC
        usdcToken.approve(HEDGER_POOL, amount);
        
        // Open new position with 5% margin (20x leverage)
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

    function _step6_UserMints500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        uint256 usdcNeeded = (500 * 1e18 * currentPrice) / 1e30;
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0);

        _captureStats("User mints 500 QEURO");
    }

    function _step7_HedgerAdds50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);
        IERC20 usdcToken = IERC20(USDC);

        console2.log("--- Step 7: Opening New Hedger Position ---");
        console2.log("Opening third position for hedger address:", hedger);

        uint256 amount = 50 * 1e6; // 50 USDC
        usdcToken.approve(HEDGER_POOL, amount);
        
        // Open new position with 5% margin (20x leverage)
        uint256 leverage = 20; // 5% margin = 20x leverage
        console2.log(string.concat("Opening new position with leverage: ", vm.toString(leverage), "x"));
        
        try hedgerPool.enterHedgePosition(amount, leverage) returns (uint256 positionId) {
            latestPositionId = positionId;
            console2.log(string.concat("New position opened successfully! Position ID: ", vm.toString(positionId)));
        } catch Error(string memory reason) {
            console2.log("ERROR: Failed to open new hedger position:", reason);
            revert(string.concat("Step 7 failed: ", reason));
        } catch (bytes memory) {
            console2.log("ERROR: Failed to open new hedger position (low-level error)");
            revert("Step 7 failed: HedgerPool contract call reverted");
        }
        console2.log("");

        _captureStats("Hedger opens new position with 50 USDC");
    }

    function _step8_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.11");
    }

    function _step9_UserMints861QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        uint256 usdcNeeded = (861 * 1e18 * currentPrice) / 1e30;
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0);

        _captureStats("User mints 861 QEURO");
    }

    function _step10_UserMints1000QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        IERC20 usdcToken = IERC20(USDC);

        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        uint256 usdcNeeded = (1000 * 1e18 * currentPrice) / 1e30;
        
        usdcToken.approve(VAULT, usdcNeeded);
        vault.mintQEURO(usdcNeeded, 0);

        _captureStats("User mints 1000 QEURO");
    }

    function _step11_UserRedeems1861QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 1861 * 1e18;
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

        _captureStats("User redeems 1861 QEURO");
    }

    function _step12_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.15");
    }

    function _step13_HedgerRemoves50USDC() internal {
        HedgerPool hedgerPool = HedgerPool(HEDGER_POOL);

        uint256 totalAmountToRemove = 50 * 1e6; // 50 USDC
        uint256 nextPositionId = hedgerPool.nextPositionId();
        
        console2.log("--- Step 13: Removing Margin from Positions ---");
        console2.log("Target: Remove 50 USDC total, spreading across available positions");
        
        uint256 remainingToRemove = totalAmountToRemove;
        
        // Get current price and core parameters for upfront calculations
        IChainlinkOracle oracle = IChainlinkOracle(ORACLE);
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Invalid oracle price");
        
        (, uint64 liquidationThreshold, , , , , , , , ) = hedgerPool.coreParams();
        
        // Iterate through positions and calculate maximum removable amount upfront
        for (uint256 id = 1; id < nextPositionId && remainingToRemove > 0; id++) {
            (address positionHedger, , uint96 filledVolume, uint96 margin, , , , int128 unrealizedPnL, int128 realizedPnL, uint16 leverage, bool isActive, uint128 qeuroBacked) = hedgerPool.positions(id);
            
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

    function _step14_SetOraclePrice(uint256 price) internal {
        _setOraclePriceIncremental(price);
        _captureStats("Oracle -> 1.16");
    }

    function _step15_UserRedeems500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 500 * 1e18;
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

        _captureStats("User redeems 500 QEURO");
    }

    function _step16_UserRedeems500QEURO() internal {
        QuantillonVault vault = QuantillonVault(VAULT);
        QEUROToken qeuroToken = QEUROToken(QEURO);
        // Use latest position ID if available, otherwise default to 1
        uint256 positionId = latestPositionId > 0 ? latestPositionId : 1;

        uint256 qeuroAmount = 500 * 1e18;
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

        _captureStats("User redeems 500 QEURO (no QEURO left circulating)");
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
            
            // Format collateralization percentage to 2 decimal places
            uint256 wholePart = stat.collateralizationPercentage / 100;
            uint256 decimalPart = stat.collateralizationPercentage % 100;
            string memory collatPctFormatted = string.concat(
                vm.toString(wholePart),
                ".",
                decimalPart < 10 ? "0" : "",
                vm.toString(decimalPart)
            );

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

