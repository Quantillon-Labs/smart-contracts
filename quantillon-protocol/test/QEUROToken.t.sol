// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ErrorLibrary} from "../src/libraries/ErrorLibrary.sol";


/**
 * @title QEUROTokenTest
 * @notice Comprehensive test suite for the QEUROToken contract
 * 
 * @dev This test suite covers:
 *      - Contract initialization and setup
 *      - Minting and burning functionality
 *      - Rate limiting mechanisms
 *      - Compliance features (blacklist/whitelist)
 *      - Emergency functions (pause/unpause)
 *      - Administrative functions
 *      - Edge cases and security scenarios
 * 
 * @dev Test categories:
 *      - Setup and Initialization
 *      - Core Token Functions
 *      - Rate Limiting
 *      - Compliance Management
 *      - Emergency Functions
 *      - Administrative Functions
 *      - Edge Cases and Security
 *      - Integration Tests
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract QEUROTokenTestSuite is Test {
    // =============================================================================
    // TEST CONTRACTS AND ADDRESSES
    // =============================================================================
    
    QEUROToken public implementation;
    QEUROToken public qeuroToken;
    
    // Test addresses
    address public admin = address(0x1);
    address public vault = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);
    address public compliance = address(0x6);
    
    // Test amounts
    uint256 public constant INITIAL_MINT_AMOUNT = 1000 * 1e18; // 1000 QEURO
    uint256 public constant SMALL_AMOUNT = 100 * 1e18; // 100 QEURO
    uint256 public constant LARGE_AMOUNT = 10000 * 1e18; // 10000 QEURO
    
    // =============================================================================
    // EVENTS FOR TESTING
    // =============================================================================
    
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurned(address indexed from, uint256 amount, address indexed burner);
    event SupplyCapUpdated(uint256 oldCap, uint256 newCap);
    event RateLimitsUpdated(uint256 mintLimit, uint256 burnLimit);
    event AddressBlacklisted(address indexed account, string reason);
    event AddressUnblacklisted(address indexed account);
    event AddressWhitelisted(address indexed account);
    event AddressUnwhitelisted(address indexed account);
    event WhitelistModeToggled(bool enabled);
    event MinPricePrecisionUpdated(uint256 oldPrecision, uint256 newPrecision);
    event RateLimitReset(uint256 timestamp);

    // =============================================================================
    // SETUP AND TEARDOWN
    // =============================================================================
    
    /**
     * @notice Set up test environment before each test
     * @dev Deploys a new QEUROToken contract using proxy pattern and initializes it
     * @custom:security Uses proxy pattern for upgradeable contract testing
     * @custom:validation No input validation required - setup function
     * @custom:state-changes Deploys new contracts and initializes state
     * @custom:events No events emitted during setup
     * @custom:errors No errors thrown - setup function
     * @custom:reentrancy Not applicable - setup function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependency for setup
     */
    function setUp() public {
        // Deploy implementation
        implementation = new QEUROToken();
        
        // Create mock timelock address
        address mockTimelock = address(0x123);
        
        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            vault,
            mockTimelock,
            admin // Use admin as treasury for testing
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        qeuroToken = QEUROToken(address(proxy));
        
        // Grant compliance role to compliance address
        vm.prank(admin);
        qeuroToken.grantRole(keccak256("COMPLIANCE_ROLE"), compliance);
    }

    // =============================================================================
    // INITIALIZATION TESTS
    // =============================================================================
    
    /**
     * @notice Test contract initialization with valid parameters
     * @dev Verifies that the QEUROToken contract initializes correctly with proper roles and state
     * @custom:security Validates role assignments and initial state setup
     * @custom:validation Checks admin, vault, and treasury addresses are set correctly
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted - view function
     * @custom:errors No errors thrown - view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependency for initialization test
     */
    function testInitialization_WithValidParameters_ShouldInitializeCorrectly() public view {
        // Check token details
        assertEq(qeuroToken.name(), "Quantillon Euro");
        assertEq(qeuroToken.symbol(), "QEURO");
        assertEq(qeuroToken.decimals(), 18);
        assertEq(qeuroToken.totalSupply(), 0);
        
        // Check roles are properly assigned
        assertTrue(qeuroToken.hasRole(qeuroToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(qeuroToken.hasRole(keccak256("COMPLIANCE_ROLE"), compliance));
        
        // Check initial state variables - only check what's actually available
        assertEq(qeuroToken.name(), "Quantillon Euro");
        assertEq(qeuroToken.symbol(), "QEURO");
        assertEq(qeuroToken.decimals(), 18);
        assertEq(qeuroToken.totalSupply(), 0);
    }
    
    /**
     * @notice Test initialization with zero addresses should revert
     * @dev Verifies that initialization fails with invalid parameters
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Initialization_ZeroAddresses_Revert() public {
        QEUROToken newImplementation = new QEUROToken();
        
        // Test with zero admin
        bytes memory initData1 = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            address(0),
            vault,
            address(0x123),
            admin
        );
        
        vm.expectRevert(ErrorLibrary.InvalidAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData1);
        
        // Test with zero vault
        QEUROToken newImplementation2 = new QEUROToken();
        bytes memory initData2 = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            address(0),
            address(0x123),
            admin
        );
        
        vm.expectRevert(ErrorLibrary.InvalidAddress.selector);
        new ERC1967Proxy(address(newImplementation2), initData2);
    }
    
    /**
     * @notice Test that initialization can only be called once
     * @dev Verifies the initializer modifier works correctly
     * @custom:security No security implications - test function
     * @custom:validation No input validation required - test function
     * @custom:state-changes No state changes - test function
     * @custom:events No events emitted - test function
     * @custom:errors No errors thrown - test function
     * @custom:reentrancy Not applicable - test function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependency for test function
     */
    function test_Initialization_CalledTwice_Revert() public {
        // Try to call initialize again on the proxy
        vm.expectRevert();
        qeuroToken.initialize(admin, vault, address(0x123), admin);
    }

    // =============================================================================
    // MINTING TESTS
    // =============================================================================
    
    /**
     * @notice Test successful token minting by vault
     * @dev Verifies that the vault can mint tokens to users successfully
     * @custom:security Validates vault role permissions and minting mechanics
     * @custom:validation Checks vault has MINTER_ROLE and can mint to valid addresses
     * @custom:state-changes Mints tokens to user1, updates total supply and balances
     * @custom:events Emits TokensMinted event with correct parameters
     * @custom:errors No errors thrown - successful mint test
     * @custom:reentrancy Not applicable - test function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependency for minting test
     */
    function test_Mint_Success() public {
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        assertEq(qeuroToken.balanceOf(user1), INITIAL_MINT_AMOUNT);
        assertEq(qeuroToken.totalSupply(), INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting by non-vault address should revert
     * @dev Verifies that only the vault can mint tokens
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Mint_NonVault_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.mint(user2, INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting to zero address should revert
     * @dev Verifies that minting to zero address is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Mint_ZeroAddress_Revert() public {
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.InvalidAddress.selector);
        qeuroToken.mint(address(0), INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting zero amount should revert
     * @dev Verifies that minting zero tokens is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Mint_ZeroAmount_Revert() public {
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        qeuroToken.mint(user1, 0);
    }
    
    /**
     * @notice Test minting to blacklisted address should revert
     * @dev Verifies that blacklisted addresses cannot receive tokens
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Mint_BlacklistedAddress_Revert() public {
        // Blacklist user1
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        // Try to mint to blacklisted address
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.BlacklistedAddress.selector);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting when whitelist is enabled
     * @dev Verifies whitelist functionality works correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Mint_WhitelistEnabled() public {
        // Enable whitelist
        vm.prank(compliance);
        qeuroToken.toggleWhitelistMode(true);
        
        // Try to mint to non-whitelisted address
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.NotWhitelisted.selector);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Whitelist user1
        vm.prank(compliance);
        qeuroToken.whitelistAddress(user1);
        
        // Now minting should work
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        assertEq(qeuroToken.balanceOf(user1), INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting exceeds supply cap should revert
     * @dev Verifies that minting cannot exceed the maximum supply
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Mint_ExceedsSupplyCap_Revert() public {
        uint256 maxSupply = qeuroToken.maxSupply();
        
        // Mint up to max supply (this will hit rate limit, so we need to do it in chunks)
        uint256 rateLimit = qeuroToken.mintRateLimit();
        uint256 remaining = maxSupply;
        
        while (remaining > 0) {
            uint256 toMint = remaining > rateLimit ? rateLimit : remaining;
            vm.prank(vault);
            qeuroToken.mint(user1, toMint);
            remaining -= toMint;
            
            // Advance blocks to reset rate limit if needed (300 blocks = ~1 hour)
            if (remaining > 0) {
                vm.roll(block.number + 300);
            }
        }
        
        // Try to mint one more token - should hit supply cap directly
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.WouldExceedLimit.selector);
        qeuroToken.mint(user2, 1);
    }

    // =============================================================================
    // BURNING TESTS
    // =============================================================================
    
    /**
     * @notice Test successful burning by vault
     * @dev Verifies that the vault can burn tokens from users
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Burn_Success() public {
        // First mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Then burn them
        vm.prank(vault);
        qeuroToken.burn(user1, SMALL_AMOUNT);
        
        assertEq(qeuroToken.balanceOf(user1), INITIAL_MINT_AMOUNT - SMALL_AMOUNT);
        assertEq(qeuroToken.totalSupply(), INITIAL_MINT_AMOUNT - SMALL_AMOUNT);
    }

    // =============================================================================
    // BATCH FUNCTION TESTS
    // =============================================================================

    /**
     * @notice Tests successful batch minting of QEURO tokens
     * @dev Validates that multiple mint operations can be performed in a single transaction
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchMint_Success() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 * 1e18;
        amounts[1] = 200 * 1e18;

        vm.prank(vault);
        qeuroToken.batchMint(recipients, amounts);

        assertEq(qeuroToken.balanceOf(user1), amounts[0]);
        assertEq(qeuroToken.balanceOf(user2), amounts[1]);
        assertEq(qeuroToken.totalSupply(), amounts[0] + amounts[1]);
    }

    /**
     * @notice Tests that batch minting reverts when array lengths don't match
     * @dev Validates that recipient and amount arrays must have matching lengths
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchMint_ArrayLengthMismatch_Revert() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 * 1e18;

        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.ArrayLengthMismatch.selector);
        qeuroToken.batchMint(recipients, amounts);
    }

    /**
     * @notice Tests successful batch burning of QEURO tokens
     * @dev Validates that multiple burn operations can be performed in a single transaction
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchBurn_Success() public {
        // Mint first
        vm.prank(vault);
        qeuroToken.mint(user1, 300 * 1e18);
        vm.prank(vault);
        qeuroToken.mint(user2, 400 * 1e18);

        address[] memory froms = new address[](2);
        froms[0] = user1;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 * 1e18;
        amounts[1] = 200 * 1e18;

        vm.prank(vault);
        qeuroToken.batchBurn(froms, amounts);

        assertEq(qeuroToken.balanceOf(user1), 200 * 1e18);
        assertEq(qeuroToken.balanceOf(user2), 200 * 1e18);
    }

    /**
     * @notice Tests successful batch transfer of QEURO tokens
     * @dev Validates that multiple transfer operations can be performed in a single transaction
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchTransfer_Success() public {
        // Mint to user1
        vm.prank(vault);
        qeuroToken.mint(user1, 500 * 1e18);

        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 * 1e18;
        amounts[1] = 150 * 1e18;

        vm.prank(user1);
        qeuroToken.batchTransfer(recipients, amounts);

        assertEq(qeuroToken.balanceOf(user1), 250 * 1e18);
        assertEq(qeuroToken.balanceOf(user2), 100 * 1e18);
        assertEq(qeuroToken.balanceOf(user3), 150 * 1e18);
    }

    /**
     * @notice Tests batch compliance operations with whitelist and blacklist
     * @dev Validates that batch compliance checks work correctly with access controls
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchCompliance_WhitelistAndBlacklist() public {
        // Batch whitelist
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        vm.prank(compliance);
        qeuroToken.batchWhitelistAddresses(accounts);
        assertTrue(qeuroToken.isWhitelisted(user1));
        assertTrue(qeuroToken.isWhitelisted(user2));

        // Batch unwhitelist
        vm.prank(compliance);
        qeuroToken.batchUnwhitelistAddresses(accounts);
        assertFalse(qeuroToken.isWhitelisted(user1));
        assertFalse(qeuroToken.isWhitelisted(user2));

        // Batch blacklist
        string[] memory reasons = new string[](2);
        reasons[0] = "r1";
        reasons[1] = "r2";
        vm.prank(compliance);
        qeuroToken.batchBlacklistAddresses(accounts, reasons);
        assertTrue(qeuroToken.isBlacklisted(user1));
        assertTrue(qeuroToken.isBlacklisted(user2));

        // Batch unblacklist
        vm.prank(compliance);
        qeuroToken.batchUnblacklistAddresses(accounts);
        assertFalse(qeuroToken.isBlacklisted(user1));
        assertFalse(qeuroToken.isBlacklisted(user2));
    }

    // =============================================================================
    // BATCH SIZE LIMIT TESTS
    // =============================================================================

    /**
     * @notice Tests that batch minting reverts when batch size exceeds limit
     * @dev Validates that the batch size limit is enforced for mint operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchMint_BatchSizeTooLarge_Revert() public {
        // Create array larger than MAX_BATCH_SIZE (100)
        address[] memory recipients = new address[](101);
        uint256[] memory amounts = new uint256[](101);
        
        for (uint256 i = 0; i < 101; i++) {
            recipients[i] = address(uint160(i + 1000)); // Generate unique addresses
            amounts[i] = 1e18;
        }

        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.BatchSizeTooLarge.selector);
        qeuroToken.batchMint(recipients, amounts);
    }

    /**
     * @notice Tests that batch burning reverts when batch size exceeds limit
     * @dev Validates that the batch size limit is enforced for burn operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchBurn_BatchSizeTooLarge_Revert() public {
        // Create array larger than MAX_BATCH_SIZE (100)
        address[] memory froms = new address[](101);
        uint256[] memory amounts = new uint256[](101);
        
        for (uint256 i = 0; i < 101; i++) {
            froms[i] = address(uint160(i + 1000)); // Generate unique addresses
            amounts[i] = 1e18;
        }

        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.BatchSizeTooLarge.selector);
        qeuroToken.batchBurn(froms, amounts);
    }

    /**
     * @notice Tests that batch transfer reverts when batch size exceeds limit
     * @dev Validates that the batch size limit is enforced for transfer operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchTransfer_BatchSizeTooLarge_Revert() public {
        // Create array larger than MAX_BATCH_SIZE (100)
        address[] memory recipients = new address[](101);
        uint256[] memory amounts = new uint256[](101);
        
        for (uint256 i = 0; i < 101; i++) {
            recipients[i] = address(uint160(i + 1000)); // Generate unique addresses
            amounts[i] = 1e18;
        }

        vm.prank(user1);
        vm.expectRevert(ErrorLibrary.BatchSizeTooLarge.selector);
        qeuroToken.batchTransfer(recipients, amounts);
    }

    /**
     * @notice Tests that batch compliance reverts when batch size exceeds limit
     * @dev Validates that the batch size limit is enforced for compliance operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchCompliance_BatchSizeTooLarge_Revert() public {
        // Create array larger than MAX_COMPLIANCE_BATCH_SIZE (50)
        address[] memory accounts = new address[](51);
        
        for (uint256 i = 0; i < 51; i++) {
            accounts[i] = address(uint160(i + 1000)); // Generate unique addresses
        }

        vm.prank(compliance);
        vm.expectRevert(ErrorLibrary.BatchSizeTooLarge.selector);
        qeuroToken.batchWhitelistAddresses(accounts);
    }

    /**
     * @notice Tests successful batch compliance at maximum batch size
     * @dev Validates that compliance operations work correctly at the maximum allowed batch size
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchCompliance_MaxBatchSize_Success() public {
        // Test with exactly MAX_BATCH_SIZE (100)
        address[] memory recipients = new address[](100);
        uint256[] memory amounts = new uint256[](100);
        
        for (uint256 i = 0; i < 100; i++) {
            recipients[i] = address(uint160(i + 1000)); // Generate unique addresses
            amounts[i] = 1e18;
        }

        vm.prank(vault);
        qeuroToken.batchMint(recipients, amounts);

        // Verify all recipients received tokens
        for (uint256 i = 0; i < 100; i++) {
            assertEq(qeuroToken.balanceOf(recipients[i]), 1e18);
        }
    }

    /**
     * @notice Tests successful batch compliance at maximum compliance batch size
     * @dev Validates that compliance operations work correctly at the maximum allowed compliance batch size
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchCompliance_MaxComplianceBatchSize_Success() public {
        // Test with exactly MAX_COMPLIANCE_BATCH_SIZE (50)
        address[] memory accounts = new address[](50);
        
        for (uint256 i = 0; i < 50; i++) {
            accounts[i] = address(uint160(i + 1000)); // Generate unique addresses
        }

        vm.prank(compliance);
        qeuroToken.batchWhitelistAddresses(accounts);

        // Verify all accounts are whitelisted
        for (uint256 i = 0; i < 50; i++) {
            assertTrue(qeuroToken.isWhitelisted(accounts[i]));
        }
    }
    
    /**
     * @notice Test burning by non-vault address should revert
     * @dev Verifies that only the vault can burn tokens
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Burn_NonVault_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.burn(user2, SMALL_AMOUNT);
    }
    
    /**
     * @notice Test burning from zero address should revert
     * @dev Verifies that burning from zero address is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Burn_ZeroAddress_Revert() public {
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.InvalidAddress.selector);
        qeuroToken.burn(address(0), SMALL_AMOUNT);
    }
    
    /**
     * @notice Test burning zero amount should revert
     * @dev Verifies that burning zero tokens is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Burn_ZeroAmount_Revert() public {
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        qeuroToken.burn(user1, 0);
    }
    
    /**
     * @notice Test burning more than balance should revert
     * @dev Verifies that burning cannot exceed user's balance
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Burn_InsufficientBalance_Revert() public {
        // Mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, SMALL_AMOUNT);
        
        // Try to burn more than balance
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.InsufficientBalance.selector);
        qeuroToken.burn(user1, LARGE_AMOUNT);
    }

    // =============================================================================
    // RATE LIMITING TESTS
    // =============================================================================
    
    /**
     * @notice Test rate limiting for minting within limits
     * @dev Verifies that minting within rate limits works correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_MintWithinLimit() public {
        uint256 rateLimit = qeuroToken.mintRateLimit();
        
        // Mint up to the rate limit
        vm.prank(vault);
        qeuroToken.mint(user1, rateLimit);
        
        assertEq(qeuroToken.balanceOf(user1), rateLimit);
    }
    
    /**
     * @notice Test rate limiting for minting exceeds limit
     * @dev Verifies that minting beyond rate limit is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_MintExceedsLimit_Revert() public {
        uint256 rateLimit = qeuroToken.mintRateLimit();
        
        // Mint up to the rate limit
        vm.prank(vault);
        qeuroToken.mint(user1, rateLimit);
        
        // Try to mint one more token
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.RateLimitExceeded.selector);
        qeuroToken.mint(user2, 1);
    }
    
    /**
     * @notice Test rate limiting for burning within limits
     * @dev Verifies that burning within rate limits works correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_BurnWithinLimit() public {
        uint256 rateLimit = qeuroToken.burnRateLimit();
        
        // Mint tokens first
        vm.prank(vault);
        qeuroToken.mint(user1, rateLimit);
        
        // Burn up to the rate limit
        vm.prank(vault);
        qeuroToken.burn(user1, rateLimit);
        
        assertEq(qeuroToken.balanceOf(user1), 0);
    }
    
    /**
     * @notice Test rate limiting for burning exceeds limit
     * @dev Verifies that burning beyond rate limit is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_BurnExceedsLimit_Revert() public {
        uint256 rateLimit = qeuroToken.burnRateLimit();
        
        // Mint tokens first (need to handle rate limiting)
        uint256 totalToMint = rateLimit + 1;
        uint256 mintRateLimit = qeuroToken.mintRateLimit();
        
        if (totalToMint > mintRateLimit) {
            // Mint in chunks
            uint256 remaining = totalToMint;
            while (remaining > 0) {
                uint256 toMint = remaining > mintRateLimit ? mintRateLimit : remaining;
                vm.prank(vault);
                qeuroToken.mint(user1, toMint);
                remaining -= toMint;
                
                if (remaining > 0) {
                    vm.roll(block.number + 300); // Advance 300 blocks (~1 hour)
                }
            }
        } else {
            vm.prank(vault);
            qeuroToken.mint(user1, totalToMint);
        }
        
        // Burn up to the rate limit
        vm.prank(vault);
        qeuroToken.burn(user1, rateLimit);
        
        // Try to burn one more token
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.RateLimitExceeded.selector);
        qeuroToken.burn(user1, 1);
    }
    
    /**
     * @notice Test rate limit reset after one hour
     * @dev Verifies that rate limits reset after the time period
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_ResetAfterOneHour() public {
        uint256 rateLimit = qeuroToken.mintRateLimit();
        
        // Mint up to the rate limit
        vm.prank(vault);
        qeuroToken.mint(user1, rateLimit);
        
        // Advance blocks by 1 hour (300 blocks at 12 seconds per block)
        vm.roll(block.number + 300);
        
        // Now should be able to mint again
        vm.prank(vault);
        qeuroToken.mint(user2, rateLimit);
        
        assertEq(qeuroToken.balanceOf(user2), rateLimit);
    }
    
    /**
     * @notice Test rate limit update by admin
     * @dev Verifies that admin can update rate limits
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_UpdateByAdmin() public {
        uint256 newMintLimit = 1000 * 1e18;
        uint256 newBurnLimit = 2000 * 1e18;
        
        vm.prank(admin);
        qeuroToken.updateRateLimits(newMintLimit, newBurnLimit);
        
        assertEq(qeuroToken.mintRateLimit(), newMintLimit);
        assertEq(qeuroToken.burnRateLimit(), newBurnLimit);
    }
    
    /**
     * @notice Test rate limit update by non-admin should revert
     * @dev Verifies that only admin can update rate limits
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_UpdateByNonAdmin_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.updateRateLimits(1000 * 1e18, 2000 * 1e18);
    }
    
    /**
     * @notice Test rate limit update with invalid values should revert
     * @dev Verifies validation of rate limit parameters
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_RateLimit_UpdateInvalidValues_Revert() public {
        // Test zero values
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        qeuroToken.updateRateLimits(0, 1000 * 1e18);
        
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        qeuroToken.updateRateLimits(1000 * 1e18, 0);
        
        // Test values too high
        uint256 tooHigh = 10_000_000 * 1e18 + 1; // MAX_RATE_LIMIT + 1
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.RateLimitTooHigh.selector);
        qeuroToken.updateRateLimits(tooHigh, 1000 * 1e18);
        
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.RateLimitTooHigh.selector);
        qeuroToken.updateRateLimits(1000 * 1e18, tooHigh);
    }

    // =============================================================================
    // COMPLIANCE TESTS
    // =============================================================================
    
    /**
     * @notice Test blacklisting an address
     * @dev Verifies that compliance role can blacklist addresses
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_BlacklistAddress() public {
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        assertTrue(qeuroToken.isBlacklisted(user1));
    }
    
    /**
     * @notice Test blacklisting by non-compliance role should revert
     * @dev Verifies that only compliance role can blacklist
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_BlacklistByNonCompliance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.blacklistAddress(user2, "Test blacklist");
    }
    
    /**
     * @notice Test blacklisting zero address should revert
     * @dev Verifies that zero address cannot be blacklisted
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_BlacklistZeroAddress_Revert() public {
        vm.prank(compliance);
        vm.expectRevert(ErrorLibrary.InvalidAddress.selector);
        qeuroToken.blacklistAddress(address(0), "Test blacklist");
    }
    
    /**
     * @notice Test blacklisting already blacklisted address should revert
     * @dev Verifies that already blacklisted addresses cannot be blacklisted again
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_BlacklistAlreadyBlacklisted_Revert() public {
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        vm.prank(compliance);
        vm.expectRevert(ErrorLibrary.AlreadyBlacklisted.selector);
        qeuroToken.blacklistAddress(user1, "Test blacklist again");
    }
    
    /**
     * @notice Test unblacklisting an address
     * @dev Verifies that compliance role can remove addresses from blacklist
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_UnblacklistAddress() public {
        // First blacklist
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        // Then unblacklist
        vm.prank(compliance);
        qeuroToken.unblacklistAddress(user1);
        
        assertFalse(qeuroToken.isBlacklisted(user1));
    }
    
    /**
     * @notice Test unblacklisting non-blacklisted address should revert
     * @dev Verifies that only blacklisted addresses can be unblacklisted
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_UnblacklistNonBlacklisted_Revert() public {
        vm.prank(compliance);
        vm.expectRevert(ErrorLibrary.NotBlacklisted.selector);
        qeuroToken.unblacklistAddress(user1);
    }
    
    /**
     * @notice Test whitelisting an address
     * @dev Verifies that compliance role can whitelist addresses
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_WhitelistAddress() public {
        vm.prank(compliance);
        qeuroToken.whitelistAddress(user1);
        
        assertTrue(qeuroToken.isWhitelisted(user1));
    }
    
    /**
     * @notice Test whitelisting by non-compliance role should revert
     * @dev Verifies that only compliance role can whitelist
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_WhitelistByNonCompliance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.whitelistAddress(user2);
    }
    
    /**
     * @notice Test whitelisting zero address should revert
     * @dev Verifies that zero address cannot be whitelisted
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_WhitelistZeroAddress_Revert() public {
        vm.prank(compliance);
        vm.expectRevert(ErrorLibrary.InvalidAddress.selector);
        qeuroToken.whitelistAddress(address(0));
    }
    
    /**
     * @notice Test whitelisting already whitelisted address should revert
     * @dev Verifies that already whitelisted addresses cannot be whitelisted again
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_WhitelistAlreadyWhitelisted_Revert() public {
        vm.prank(compliance);
        qeuroToken.whitelistAddress(user1);
        
        vm.prank(compliance);
        vm.expectRevert(ErrorLibrary.AlreadyWhitelisted.selector);
        qeuroToken.whitelistAddress(user1);
    }
    
    /**
     * @notice Test unwhitelisting an address
     * @dev Verifies that compliance role can remove addresses from whitelist
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_UnwhitelistAddress() public {
        // First whitelist
        vm.prank(compliance);
        qeuroToken.whitelistAddress(user1);
        
        // Then unwhitelist
        vm.prank(compliance);
        qeuroToken.unwhitelistAddress(user1);
        
        assertFalse(qeuroToken.isWhitelisted(user1));
    }
    
    /**
     * @notice Test unwhitelisting non-whitelisted address should revert
     * @dev Verifies that only whitelisted addresses can be unwhitelisted
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_UnwhitelistNonWhitelisted_Revert() public {
        vm.prank(compliance);
        vm.expectRevert(ErrorLibrary.NotWhitelisted.selector);
        qeuroToken.unwhitelistAddress(user1);
    }
    
    /**
     * @notice Test toggling whitelist mode
     * @dev Verifies that compliance role can toggle whitelist mode
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_ToggleWhitelistMode() public {
        // Enable whitelist
        vm.prank(compliance);
        qeuroToken.toggleWhitelistMode(true);
        assertTrue(qeuroToken.whitelistEnabled());
        
        // Disable whitelist
        vm.prank(compliance);
        qeuroToken.toggleWhitelistMode(false);
        assertFalse(qeuroToken.whitelistEnabled());
    }
    
    /**
     * @notice Test toggling whitelist mode by non-compliance role should revert
     * @dev Verifies that only compliance role can toggle whitelist mode
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Compliance_ToggleWhitelistByNonCompliance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.toggleWhitelistMode(true);
    }

    // =============================================================================
    // EMERGENCY TESTS
    // =============================================================================
    
    /**
     * @notice Test pausing the contract
     * @dev Verifies that pauser role can pause the contract
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_Pause() public {
        vm.prank(admin);
        qeuroToken.pause();
        
        assertTrue(qeuroToken.paused());
    }
    
    /**
     * @notice Test pausing by non-pauser role should revert
     * @dev Verifies that only pauser role can pause
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_PauseByNonPauser_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.pause();
    }
    
    /**
     * @notice Test unpausing the contract
     * @dev Verifies that pauser role can unpause the contract
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_Unpause() public {
        // First pause
        vm.prank(admin);
        qeuroToken.pause();
        
        // Then unpause
        vm.prank(admin);
        qeuroToken.unpause();
        
        assertFalse(qeuroToken.paused());
    }
    
    /**
     * @notice Test unpausing by non-pauser role should revert
     * @dev Verifies that only pauser role can unpause
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_UnpauseByNonPauser_Revert() public {
        // First pause
        vm.prank(admin);
        qeuroToken.pause();
        
        // Try to unpause with non-pauser
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.unpause();
    }
    
    /**
     * @notice Test minting when paused should revert
     * @dev Verifies that minting is blocked when contract is paused
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_MintWhenPaused_Revert() public {
        vm.prank(admin);
        qeuroToken.pause();
        
        vm.prank(vault);
        vm.expectRevert();
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test burning when paused should revert
     * @dev Verifies that burning is blocked when contract is paused
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_BurnWhenPaused_Revert() public {
        // First mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Then pause
        vm.prank(admin);
        qeuroToken.pause();
        
        // Try to burn
        vm.prank(vault);
        vm.expectRevert();
        qeuroToken.burn(user1, SMALL_AMOUNT);
    }

    // =============================================================================
    // ADMINISTRATIVE TESTS
    // =============================================================================
    
    /**
     * @notice Test updating maximum supply
     * @dev Verifies that admin can update the maximum supply
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMaxSupply() public {
        uint256 newMaxSupply = 200_000_000 * 1e18;
        
        vm.prank(admin);
        qeuroToken.updateMaxSupply(newMaxSupply);
        
        assertEq(qeuroToken.maxSupply(), newMaxSupply);
    }
    
    /**
     * @notice Test updating max supply by non-admin should revert
     * @dev Verifies that only admin can update maximum supply
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMaxSupplyByNonAdmin_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.updateMaxSupply(200_000_000 * 1e18);
    }
    
    /**
     * @notice Test updating max supply below current supply should revert
     * @dev Verifies that max supply cannot be set below current supply
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMaxSupplyBelowCurrent_Revert() public {
        // Mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Try to set max supply below current supply
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.NewCapBelowCurrentSupply.selector);
        qeuroToken.updateMaxSupply(SMALL_AMOUNT);
    }
    
    /**
     * @notice Test updating max supply to zero should revert
     * @dev Verifies that max supply cannot be set to zero
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMaxSupplyToZero_Revert() public {
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        qeuroToken.updateMaxSupply(0);
    }
    
    /**
     * @notice Test updating minimum price precision
     * @dev Verifies that admin can update minimum price precision
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMinPricePrecision() public {
        uint256 newPrecision = 1e6;
        
        vm.prank(admin);
        qeuroToken.updateMinPricePrecision(newPrecision);
        
        assertEq(qeuroToken.minPricePrecision(), newPrecision);
    }
    
    /**
     * @notice Test updating min price precision by non-admin should revert
     * @dev Verifies that only admin can update minimum price precision
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMinPricePrecisionByNonAdmin_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.updateMinPricePrecision(1e6);
    }
    
    /**
     * @notice Test updating min price precision to zero should revert
     * @dev Verifies that minimum price precision cannot be set to zero
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMinPricePrecisionToZero_Revert() public {
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        qeuroToken.updateMinPricePrecision(0);
    }
    
    /**
     * @notice Test updating min price precision too high should revert
     * @dev Verifies that minimum price precision cannot exceed PRECISION
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateMinPricePrecisionTooHigh_Revert() public {
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.PrecisionTooHigh.selector);
        qeuroToken.updateMinPricePrecision(1e19); // 1e18 + 1 would be too high
    }

    // =============================================================================
    // UTILITY FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test price normalization with different decimal precisions
     * @dev Verifies that price normalization works correctly for different feed decimals
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Utility_NormalizePrice() public view {
        // Test with 8 decimals (like Chainlink)
        uint256 price8Decimals = 100000000; // 1.00 with 8 decimals
        uint256 normalized = qeuroToken.normalizePrice(price8Decimals, 8);
        assertEq(normalized, 1000000000000000000); // 1.00 with 18 decimals
        
        // Test with 6 decimals
        uint256 price6Decimals = 1000000; // 1.00 with 6 decimals
        normalized = qeuroToken.normalizePrice(price6Decimals, 6);
        assertEq(normalized, 1000000000000000000); // 1.00 with 18 decimals
        
        // Test with 18 decimals (no change)
        uint256 price18Decimals = 1000000000000000000; // 1.00 with 18 decimals
        normalized = qeuroToken.normalizePrice(price18Decimals, 18);
        assertEq(normalized, 1000000000000000000); // 1.00 with 18 decimals
    }
    
    /**
     * @notice Test price normalization with too many decimals should revert
     * @dev Verifies that price normalization fails with invalid decimal count
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Utility_NormalizePriceTooManyDecimals_Revert() public {
        vm.expectRevert(ErrorLibrary.TooManyDecimals.selector);
        qeuroToken.normalizePrice(1000, 19);
    }
    
    /**
     * @notice Test price normalization with zero price should revert
     * @dev Verifies that price normalization fails with zero price
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Utility_NormalizePriceZeroPrice_Revert() public {
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        qeuroToken.normalizePrice(0, 8);
    }
    
    /**
     * @notice Test price precision validation
     * @dev Verifies that price precision validation works correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Utility_ValidatePricePrecision() public view {
        // Test with valid precision (normalized to 18 decimals)
        // minPrecision is 1e8, so we need a price that when normalized to 18 decimals is >= 1e8
        uint256 validPrice = 1; // 1 with 8 decimals, normalized to 18 decimals = 1e10
        bool isValid = qeuroToken.validatePricePrecision(validPrice, 8);
        assertTrue(isValid);
        
        // Test with insufficient precision
        uint256 invalidPrice = 1; // 1 with 0 decimals, normalized to 18 decimals = 1
        isValid = qeuroToken.validatePricePrecision(invalidPrice, 0);
        assertFalse(isValid);
    }
    
    /**
     * @notice Test supply utilization calculation
     * @dev Verifies that supply utilization percentage is calculated correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Utility_GetSupplyUtilization() public {
        // Initially 0% utilization
        assertEq(qeuroToken.getSupplyUtilization(), 0);
        
        // Mint a small amount and test utilization calculation
        uint256 maxSupply = qeuroToken.maxSupply();
        uint256 smallAmount = 1000 * 1e18; // 1000 QEURO
        
        vm.prank(vault);
        qeuroToken.mint(user1, smallAmount);
        
        // Calculate expected utilization (smallAmount / maxSupply * 10000)
        uint256 expectedUtilization = (smallAmount * 10000) / maxSupply;
        assertEq(qeuroToken.getSupplyUtilization(), expectedUtilization);
        
        // Test with a larger amount (but still manageable)
        uint256 largerAmount = 10000 * 1e18; // 10000 QEURO
        vm.prank(vault);
        qeuroToken.mint(user2, largerAmount);
        
        uint256 totalSupply = smallAmount + largerAmount;
        expectedUtilization = (totalSupply * 10000) / maxSupply;
        assertEq(qeuroToken.getSupplyUtilization(), expectedUtilization);
    }
    

    

    
    /**
     * @notice Test token info retrieval
     * @dev Verifies that complete token information is returned correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Utility_GetTokenInfo() public view {
        (
            string memory name_,
            string memory symbol_,
            uint8 decimals_,
            uint256 totalSupply_,
            uint256 maxSupply_,
            bool isPaused_,
            bool whitelistEnabled_,
            uint256 mintRateLimit_,
            uint256 burnRateLimit_
        ) = qeuroToken.getTokenInfo();
        
        assertEq(name_, "Quantillon Euro");
        assertEq(symbol_, "QEURO");
        assertEq(decimals_, 18);
        assertEq(totalSupply_, 0);
        assertEq(maxSupply_, 100_000_000 * 1e18); // DEFAULT_MAX_SUPPLY
        assertEq(isPaused_, false);
        assertEq(whitelistEnabled_, false);
        assertEq(mintRateLimit_, 10_000_000 * 1e18); // MAX_RATE_LIMIT
        assertEq(burnRateLimit_, 10_000_000 * 1e18); // MAX_RATE_LIMIT
    }

    // =============================================================================
    // RECOVERY TESTS
    // =============================================================================
    
    /**
     * @notice Test recovering external tokens to treasury
     * @dev Verifies that admin can recover accidentally sent tokens to treasury
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverToken() public {
        // Create a mock ERC20 token
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");
        mockToken.mint(address(qeuroToken), 1000);
        
        uint256 initialTreasuryBalance = mockToken.balanceOf(admin); // admin is treasury
        
        vm.prank(admin);
        qeuroToken.recoverToken(address(mockToken), 500);
        
        // Verify tokens were sent to treasury (admin)
        assertEq(mockToken.balanceOf(admin), initialTreasuryBalance + 500);
    }
    
    /**
     * @notice Test recovering QEURO tokens should revert
     * @dev Verifies that QEURO tokens cannot be recovered
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverQEURO_Revert() public {
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.CannotRecoverOwnToken.selector);
        qeuroToken.recoverToken(address(qeuroToken), 1000);
    }
    
    /**
     * @notice Test recovering tokens by non-admin should revert
     * @dev Verifies that only admin can recover tokens
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverTokenByNonAdmin_Revert() public {
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");
        
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.recoverToken(address(mockToken), 1000);
    }
    
    /**
     * @notice Test recovering ETH to treasury address
     * @dev Verifies that admin can recover accidentally sent ETH to treasury only
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverETH() public {
        // Send ETH to the contract
        vm.deal(address(qeuroToken), 1 ether);
        
        uint256 initialBalance = admin.balance; // admin is treasury
        
        vm.prank(admin);
        qeuroToken.recoverETH(); // Must be treasury address
        
        assertEq(admin.balance, initialBalance + 1 ether);
    }
    
    /**
     * @notice Test recovering ETH by non-admin should revert
     * @dev Verifies that only admin can recover ETH
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverETHByNonAdmin_Revert() public {
        vm.deal(address(qeuroToken), 1 ether);
        
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.recoverETH();
    }
    

    
    /**
     * @notice Test recovering ETH when no ETH available should revert
     * @dev Verifies that recovery fails when contract has no ETH
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverETHNoBalance_Revert() public {
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.NoETHToRecover.selector);
        qeuroToken.recoverETH();
    }

    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test complete mint-burn cycle
     * @dev Verifies that a complete mint and burn cycle works correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Integration_CompleteMintBurnCycle() public {
        // Mint tokens
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        assertEq(qeuroToken.balanceOf(user1), INITIAL_MINT_AMOUNT);
        assertEq(qeuroToken.totalSupply(), INITIAL_MINT_AMOUNT);
        
        // Burn tokens
        vm.prank(vault);
        qeuroToken.burn(user1, SMALL_AMOUNT);
        assertEq(qeuroToken.balanceOf(user1), INITIAL_MINT_AMOUNT - SMALL_AMOUNT);
        assertEq(qeuroToken.totalSupply(), INITIAL_MINT_AMOUNT - SMALL_AMOUNT);
        
        // Burn remaining tokens
        vm.prank(vault);
        qeuroToken.burn(user1, INITIAL_MINT_AMOUNT - SMALL_AMOUNT);
        assertEq(qeuroToken.balanceOf(user1), 0);
        assertEq(qeuroToken.totalSupply(), 0);
    }
    
    /**
     * @notice Test blacklist and whitelist integration
     * @dev Verifies that blacklist and whitelist work together correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Integration_BlacklistWhitelistIntegration() public {
        // Enable whitelist
        vm.prank(compliance);
        qeuroToken.toggleWhitelistMode(true);
        
        // Whitelist user1
        vm.prank(compliance);
        qeuroToken.whitelistAddress(user1);
        
        // Mint to whitelisted user
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Blacklist user1
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        // Try to mint to blacklisted user (should fail even if whitelisted)
        vm.prank(vault);
        vm.expectRevert(ErrorLibrary.BlacklistedAddress.selector);
        qeuroToken.mint(user1, SMALL_AMOUNT);
        
        // Unblacklist user1
        vm.prank(compliance);
        qeuroToken.unblacklistAddress(user1);
        
        // Now minting should work again
        vm.prank(vault);
        qeuroToken.mint(user1, SMALL_AMOUNT);
        assertEq(qeuroToken.balanceOf(user1), INITIAL_MINT_AMOUNT + SMALL_AMOUNT);
    }
    
    /**
     * @notice Test pause and unpause integration
     * @dev Verifies that pause functionality works with all operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Integration_PauseUnpauseIntegration() public {
        // Mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Pause the contract
        vm.prank(admin);
        qeuroToken.pause();
        
        // Try to mint (should fail)
        vm.prank(vault);
        vm.expectRevert();
        qeuroToken.mint(user2, SMALL_AMOUNT);
        
        // Try to burn (should fail)
        vm.prank(vault);
        vm.expectRevert();
        qeuroToken.burn(user1, SMALL_AMOUNT);
        
        // Unpause the contract
        vm.prank(admin);
        qeuroToken.unpause();
        
        // Now operations should work again
        vm.prank(vault);
        qeuroToken.mint(user2, SMALL_AMOUNT);
        vm.prank(vault);
        qeuroToken.burn(user1, SMALL_AMOUNT);
        
        assertEq(qeuroToken.balanceOf(user2), SMALL_AMOUNT);
        assertEq(qeuroToken.balanceOf(user1), INITIAL_MINT_AMOUNT - SMALL_AMOUNT);
    }
}

// =============================================================================
// MOCK CONTRACTS FOR TESTING
// =============================================================================

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing recovery functions
 * @dev Simple ERC20 implementation for testing purposes
 */
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @notice Initializes the mock ERC20 token
     * @dev Mock function for testing purposes
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Sets name and symbol state variables
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    /**
     * @notice Mints tokens to an address
     * @dev Mock function for testing purposes
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates balanceOf and totalSupply
     * @custom:events Emits Transfer event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @notice Transfers tokens to an address
     * @dev Mock function for testing purposes
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return True if transfer succeeded
     * @custom:security No security validations - test mock
     * @custom:validation Validates sufficient balance
     * @custom:state-changes Updates balanceOf mapping
     * @custom:events Emits Transfer event
     * @custom:errors Throws if insufficient balance
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @notice Approves a spender to spend tokens
     * @dev Mock function for testing purposes
     * @param spender The address to approve
     * @param amount The amount of tokens to approve
     * @return True if approval succeeded
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates allowance mapping
     * @custom:events Emits Approval event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @notice Transfers tokens from one address to another
     * @dev Mock function for testing purposes
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return True if transfer succeeded
     * @custom:security No security validations - test mock
     * @custom:validation Validates sufficient balance and allowance
     * @custom:state-changes Updates balanceOf and allowance mappings
     * @custom:events Emits Transfer event
     * @custom:errors Throws if insufficient balance or allowance
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
