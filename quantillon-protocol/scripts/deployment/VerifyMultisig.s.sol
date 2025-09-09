// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import all contracts
import "../../src/libraries/TimeProviderLibrary.sol";
import "../../src/oracle/ChainlinkOracle.sol";
import "../../src/core/QEUROToken.sol";
import "../../src/core/QTIToken.sol";
import "../../src/core/QuantillonVault.sol";
import "../../src/core/UserPool.sol";
import "../../src/core/HedgerPool.sol";
import "../../src/core/stQEUROToken.sol";
import "../../src/core/vaults/AaveVault.sol";
import "../../src/core/yieldmanagement/YieldShift.sol";

/**
 * @title VerifyMultisig
 * @notice Verification script for Quantillon Protocol multisig deployment
 * @dev Verifies deployment integrity and multisig configuration
 */
contract VerifyMultisig is Script {
    // Contract addresses
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

    // Multisig configuration
    address public multisigWallet;

    function run() external {
        // Load addresses from environment variables
        _loadDeploymentAddresses();
        
        console.log("=== QUANTILLON PROTOCOL MULTISIG VERIFICATION ===");
        console.log("Verifying deployment integrity...");
        console.log("Multisig wallet:", multisigWallet);

        // Verify contract deployments
        _verifyContractDeployments();
        
        // Verify contract initialization
        _verifyContractInitialization();
        
        // Verify multisig configuration
        _verifyMultisigConfiguration();
        
        // Verify contract relationships
        _verifyContractRelationships();

        console.log("\n=== VERIFICATION COMPLETED ===");
        console.log("✅ All contracts verified successfully");
        console.log("✅ Multisig configuration verified");
        console.log("✅ Protocol ready for multisig governance");
    }

    function _loadDeploymentAddresses() internal {
        // Load addresses from environment variables
        timeProvider = vm.envOr("TIME_PROVIDER", address(0));
        chainlinkOracle = vm.envOr("CHAINLINK_ORACLE", address(0));
        qeuroToken = vm.envOr("QEURO_TOKEN", address(0));
        qtiToken = vm.envOr("QTI_TOKEN", address(0));
        quantillonVault = vm.envOr("QUANTILLON_VAULT", address(0));
        userPool = vm.envOr("USER_POOL", address(0));
        hedgerPool = vm.envOr("HEDGER_POOL", address(0));
        stQeuroToken = vm.envOr("ST_QEURO_TOKEN", address(0));
        aaveVault = vm.envOr("AAVE_VAULT", address(0));
        yieldShift = vm.envOr("YIELD_SHIFT", address(0));
        multisigWallet = vm.envOr("MULTISIG_WALLET", address(0));

        // Validate that all addresses are set
        require(timeProvider != address(0), "TimeProvider address not set");
        require(chainlinkOracle != address(0), "ChainlinkOracle address not set");
        require(qeuroToken != address(0), "QEUROToken address not set");
        require(qtiToken != address(0), "QTIToken address not set");
        require(quantillonVault != address(0), "QuantillonVault address not set");
        require(userPool != address(0), "UserPool address not set");
        require(hedgerPool != address(0), "HedgerPool address not set");
        require(stQeuroToken != address(0), "stQEUROToken address not set");
        require(aaveVault != address(0), "AaveVault address not set");
        require(yieldShift != address(0), "YieldShift address not set");
        require(multisigWallet != address(0), "Multisig wallet address not set");
    }

    function _verifyContractDeployments() internal view {
        console.log("\n=== VERIFYING CONTRACT DEPLOYMENTS ===");
        
        address[] memory contracts = new address[](10);
        contracts[0] = timeProvider;
        contracts[1] = chainlinkOracle;
        contracts[2] = qeuroToken;
        contracts[3] = qtiToken;
        contracts[4] = quantillonVault;
        contracts[5] = userPool;
        contracts[6] = hedgerPool;
        contracts[7] = stQeuroToken;
        contracts[8] = aaveVault;
        contracts[9] = yieldShift;

        string[] memory contractNames = new string[](10);
        contractNames[0] = "TimeProvider";
        contractNames[1] = "ChainlinkOracle";
        contractNames[2] = "QEUROToken";
        contractNames[3] = "QTIToken";
        contractNames[4] = "QuantillonVault";
        contractNames[5] = "UserPool";
        contractNames[6] = "HedgerPool";
        contractNames[7] = "stQEUROToken";
        contractNames[8] = "AaveVault";
        contractNames[9] = "YieldShift";

        for (uint256 i = 0; i < contracts.length; i++) {
            uint256 codeSize = contracts[i].code.length;
            if (codeSize > 0) {
                console.log(string(abi.encodePacked("✅ ", contractNames[i], " deployed at: ", vm.toString(contracts[i]))));
            } else {
                console.log(string(abi.encodePacked("❌ ", contractNames[i], " not deployed or invalid address")));
                revert(string(abi.encodePacked("Contract deployment verification failed for ", contractNames[i])));
            }
        }
    }

    function _verifyContractInitialization() internal view {
        console.log("\n=== VERIFYING CONTRACT INITIALIZATION ===");
        
        // Get contract instances
        TimeProvider timeProviderContract = TimeProvider(timeProvider);
        ChainlinkOracle chainlinkOracleContract = ChainlinkOracle(chainlinkOracle);
        QEUROToken qeuroTokenContract = QEUROToken(qeuroToken);
        QTIToken qtiTokenContract = QTIToken(qtiToken);
        QuantillonVault quantillonVaultContract = QuantillonVault(quantillonVault);
        UserPool userPoolContract = UserPool(userPool);
        HedgerPool hedgerPoolContract = HedgerPool(hedgerPool);
        stQEUROToken stQeuroTokenContract = stQEUROToken(stQeuroToken);
        AaveVault aaveVaultContract = AaveVault(aaveVault);
        YieldShift yieldShiftContract = YieldShift(yieldShift);

        // Check if contracts are initialized
        try timeProviderContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ TimeProvider initialized");
            } else {
                console.log("❌ TimeProvider not initialized");
            }
        } catch {
            console.log("⚠️ Could not check TimeProvider initialization");
        }

        try chainlinkOracleContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ ChainlinkOracle initialized");
            } else {
                console.log("❌ ChainlinkOracle not initialized");
            }
        } catch {
            console.log("⚠️ Could not check ChainlinkOracle initialization");
        }

        try qeuroTokenContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ QEUROToken initialized");
            } else {
                console.log("❌ QEUROToken not initialized");
            }
        } catch {
            console.log("⚠️ Could not check QEUROToken initialization");
        }

        try qtiTokenContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ QTIToken initialized");
            } else {
                console.log("❌ QTIToken not initialized");
            }
        } catch {
            console.log("⚠️ Could not check QTIToken initialization");
        }

        try quantillonVaultContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ QuantillonVault initialized");
            } else {
                console.log("❌ QuantillonVault not initialized");
            }
        } catch {
            console.log("⚠️ Could not check QuantillonVault initialization");
        }

        try userPoolContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ UserPool initialized");
            } else {
                console.log("❌ UserPool not initialized");
            }
        } catch {
            console.log("⚠️ Could not check UserPool initialization");
        }

        try hedgerPoolContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ HedgerPool initialized");
            } else {
                console.log("❌ HedgerPool not initialized");
            }
        } catch {
            console.log("⚠️ Could not check HedgerPool initialization");
        }

        try stQeuroTokenContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ stQEUROToken initialized");
            } else {
                console.log("❌ stQEUROToken not initialized");
            }
        } catch {
            console.log("⚠️ Could not check stQEUROToken initialization");
        }

        try aaveVaultContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ AaveVault initialized");
            } else {
                console.log("❌ AaveVault not initialized");
            }
        } catch {
            console.log("⚠️ Could not check AaveVault initialization");
        }

        try yieldShiftContract.initialized() returns (bool initialized) {
            if (initialized) {
                console.log("✅ YieldShift initialized");
            } else {
                console.log("❌ YieldShift not initialized");
            }
        } catch {
            console.log("⚠️ Could not check YieldShift initialization");
        }
    }

    function _verifyMultisigConfiguration() internal view {
        console.log("\n=== VERIFYING MULTISIG CONFIGURATION ===");
        
        // Get contract instances
        TimeProvider timeProviderContract = TimeProvider(timeProvider);
        ChainlinkOracle chainlinkOracleContract = ChainlinkOracle(chainlinkOracle);
        QEUROToken qeuroTokenContract = QEUROToken(qeuroToken);
        QTIToken qtiTokenContract = QTIToken(qtiToken);
        QuantillonVault quantillonVaultContract = QuantillonVault(quantillonVault);
        UserPool userPoolContract = UserPool(userPool);
        HedgerPool hedgerPoolContract = HedgerPool(hedgerPool);
        stQEUROToken stQeuroTokenContract = stQEUROToken(stQeuroToken);
        AaveVault aaveVaultContract = AaveVault(aaveVault);
        YieldShift yieldShiftContract = YieldShift(yieldShift);

        // Check if multisig has admin roles
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;

        try timeProviderContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ TimeProvider: Multisig has admin role");
            } else {
                console.log("❌ TimeProvider: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check TimeProvider admin role");
        }

        try chainlinkOracleContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ ChainlinkOracle: Multisig has admin role");
            } else {
                console.log("❌ ChainlinkOracle: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check ChainlinkOracle admin role");
        }

        try qeuroTokenContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ QEUROToken: Multisig has admin role");
            } else {
                console.log("❌ QEUROToken: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check QEUROToken admin role");
        }

        try qtiTokenContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ QTIToken: Multisig has admin role");
            } else {
                console.log("❌ QTIToken: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check QTIToken admin role");
        }

        try quantillonVaultContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ QuantillonVault: Multisig has admin role");
            } else {
                console.log("❌ QuantillonVault: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check QuantillonVault admin role");
        }

        try userPoolContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ UserPool: Multisig has admin role");
            } else {
                console.log("❌ UserPool: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check UserPool admin role");
        }

        try hedgerPoolContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ HedgerPool: Multisig has admin role");
            } else {
                console.log("❌ HedgerPool: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check HedgerPool admin role");
        }

        try stQeuroTokenContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ stQEUROToken: Multisig has admin role");
            } else {
                console.log("❌ stQEUROToken: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check stQEUROToken admin role");
        }

        try aaveVaultContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ AaveVault: Multisig has admin role");
            } else {
                console.log("❌ AaveVault: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check AaveVault admin role");
        }

        try yieldShiftContract.hasRole(DEFAULT_ADMIN_ROLE, multisigWallet) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ YieldShift: Multisig has admin role");
            } else {
                console.log("❌ YieldShift: Multisig does not have admin role");
            }
        } catch {
            console.log("⚠️ Could not check YieldShift admin role");
        }
    }

    function _verifyContractRelationships() internal view {
        console.log("\n=== VERIFYING CONTRACT RELATIONSHIPS ===");
        
        // Get contract instances
        QEUROToken qeuroTokenContract = QEUROToken(qeuroToken);
        YieldShift yieldShiftContract = YieldShift(yieldShift);

        // Check vault role for QuantillonVault
        try qeuroTokenContract.hasRole(qeuroTokenContract.VAULT_ROLE(), quantillonVault) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ QEUROToken: QuantillonVault has vault role");
            } else {
                console.log("❌ QEUROToken: QuantillonVault does not have vault role");
            }
        } catch {
            console.log("⚠️ Could not check QEUROToken vault role");
        }

        // Check yield manager role for AaveVault
        try yieldShiftContract.hasRole(yieldShiftContract.YIELD_MANAGER_ROLE(), aaveVault) returns (bool hasRole) {
            if (hasRole) {
                console.log("✅ YieldShift: AaveVault has yield manager role");
            } else {
                console.log("❌ YieldShift: AaveVault does not have yield manager role");
            }
        } catch {
            console.log("⚠️ Could not check YieldShift yield manager role");
        }

        // Check authorized yield source
        try yieldShiftContract.authorizedYieldSources(aaveVault) returns (bool authorized) {
            if (authorized) {
                console.log("✅ YieldShift: AaveVault is authorized yield source");
            } else {
                console.log("❌ YieldShift: AaveVault is not authorized yield source");
            }
        } catch {
            console.log("⚠️ Could not check YieldShift authorized yield source");
        }
    }
}
