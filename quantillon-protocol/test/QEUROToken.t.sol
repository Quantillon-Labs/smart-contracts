// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
 * @author Quantillon Labs
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
     */
    function setUp() public {
        // Deploy implementation
        implementation = new QEUROToken();
        
        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            vault
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
     * @notice Test successful contract initialization
     * @dev Verifies that the contract is properly initialized with correct roles and settings
     */
    function test_Initialization_Success() public {
        // Check token details
        assertEq(qeuroToken.name(), "Quantillon Euro");
        assertEq(qeuroToken.symbol(), "QEURO");
        assertEq(qeuroToken.decimals(), 18);
        assertEq(qeuroToken.totalSupply(), 0);
        
        // Check roles are properly assigned
        assertTrue(qeuroToken.hasRole(0x00, admin)); // DEFAULT_ADMIN_ROLE is 0x00
        assertTrue(qeuroToken.hasRole(keccak256("MINTER_ROLE"), vault));
        assertTrue(qeuroToken.hasRole(keccak256("BURNER_ROLE"), vault));
        assertTrue(qeuroToken.hasRole(keccak256("PAUSER_ROLE"), admin));
        assertTrue(qeuroToken.hasRole(keccak256("UPGRADER_ROLE"), admin));
        assertTrue(qeuroToken.hasRole(keccak256("COMPLIANCE_ROLE"), admin));
        
        // Check initial state variables
        assertEq(qeuroToken.maxSupply(), 100_000_000 * 1e18); // DEFAULT_MAX_SUPPLY
        assertEq(qeuroToken.mintRateLimit(), 10_000_000 * 1e18); // MAX_RATE_LIMIT
        assertEq(qeuroToken.burnRateLimit(), 10_000_000 * 1e18); // MAX_RATE_LIMIT
        assertEq(qeuroToken.whitelistEnabled(), false);
        assertEq(qeuroToken.minPricePrecision(), 1e8);
    }
    
    /**
     * @notice Test initialization with zero addresses should revert
     * @dev Verifies that initialization fails with invalid parameters
     */
    function test_Initialization_ZeroAddresses_Revert() public {
        QEUROToken newImplementation = new QEUROToken();
        
        // Test with zero admin
        bytes memory initData1 = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            address(0),
            vault
        );
        
        vm.expectRevert("QEURO: Admin cannot be zero address");
        new ERC1967Proxy(address(newImplementation), initData1);
        
        // Test with zero vault
        QEUROToken newImplementation2 = new QEUROToken();
        bytes memory initData2 = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            address(0)
        );
        
        vm.expectRevert("QEURO: Vault cannot be zero address");
        new ERC1967Proxy(address(newImplementation2), initData2);
    }
    
    /**
     * @notice Test that initialization can only be called once
     * @dev Verifies the initializer modifier works correctly
     */
    function test_Initialization_CalledTwice_Revert() public {
        // Try to call initialize again on the proxy
        vm.expectRevert();
        qeuroToken.initialize(admin, vault);
    }

    // =============================================================================
    // MINTING TESTS
    // =============================================================================
    
    /**
     * @notice Test successful minting by vault
     * @dev Verifies that the vault can mint tokens to users
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
     */
    function test_Mint_NonVault_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.mint(user2, INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting to zero address should revert
     * @dev Verifies that minting to zero address is prevented
     */
    function test_Mint_ZeroAddress_Revert() public {
        vm.prank(vault);
        vm.expectRevert("QEURO: Cannot mint to zero address");
        qeuroToken.mint(address(0), INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting zero amount should revert
     * @dev Verifies that minting zero tokens is prevented
     */
    function test_Mint_ZeroAmount_Revert() public {
        vm.prank(vault);
        vm.expectRevert("QEURO: Amount must be greater than zero");
        qeuroToken.mint(user1, 0);
    }
    
    /**
     * @notice Test minting to blacklisted address should revert
     * @dev Verifies that blacklisted addresses cannot receive tokens
     */
    function test_Mint_BlacklistedAddress_Revert() public {
        // Blacklist user1
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        // Try to mint to blacklisted address
        vm.prank(vault);
        vm.expectRevert("QEURO: Recipient is blacklisted");
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
    }
    
    /**
     * @notice Test minting when whitelist is enabled
     * @dev Verifies whitelist functionality works correctly
     */
    function test_Mint_WhitelistEnabled() public {
        // Enable whitelist
        vm.prank(compliance);
        qeuroToken.toggleWhitelistMode(true);
        
        // Try to mint to non-whitelisted address
        vm.prank(vault);
        vm.expectRevert("QEURO: Recipient not whitelisted");
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
            
            // Advance time to reset rate limit if needed
            if (remaining > 0) {
                vm.warp(block.timestamp + 1 hours);
            }
        }
        
        // Try to mint one more token - should hit rate limit first, then supply cap
        vm.prank(vault);
        vm.expectRevert("QEURO: Mint rate limit exceeded");
        qeuroToken.mint(user2, 1);
        
        // Advance time to reset rate limit, then try again - should hit supply cap
        vm.warp(block.timestamp + 1 hours);
        vm.prank(vault);
        vm.expectRevert("QEURO: Would exceed max supply");
        qeuroToken.mint(user2, 1);
    }

    // =============================================================================
    // BURNING TESTS
    // =============================================================================
    
    /**
     * @notice Test successful burning by vault
     * @dev Verifies that the vault can burn tokens from users
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
    
    /**
     * @notice Test burning by non-vault address should revert
     * @dev Verifies that only the vault can burn tokens
     */
    function test_Burn_NonVault_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.burn(user2, SMALL_AMOUNT);
    }
    
    /**
     * @notice Test burning from zero address should revert
     * @dev Verifies that burning from zero address is prevented
     */
    function test_Burn_ZeroAddress_Revert() public {
        vm.prank(vault);
        vm.expectRevert("QEURO: Cannot burn from zero address");
        qeuroToken.burn(address(0), SMALL_AMOUNT);
    }
    
    /**
     * @notice Test burning zero amount should revert
     * @dev Verifies that burning zero tokens is prevented
     */
    function test_Burn_ZeroAmount_Revert() public {
        vm.prank(vault);
        vm.expectRevert("QEURO: Amount must be greater than zero");
        qeuroToken.burn(user1, 0);
    }
    
    /**
     * @notice Test burning more than balance should revert
     * @dev Verifies that burning cannot exceed user's balance
     */
    function test_Burn_InsufficientBalance_Revert() public {
        // Mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, SMALL_AMOUNT);
        
        // Try to burn more than balance
        vm.prank(vault);
        vm.expectRevert("QEURO: Insufficient balance to burn");
        qeuroToken.burn(user1, LARGE_AMOUNT);
    }

    // =============================================================================
    // RATE LIMITING TESTS
    // =============================================================================
    
    /**
     * @notice Test rate limiting for minting within limits
     * @dev Verifies that minting within rate limits works correctly
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
     */
    function test_RateLimit_MintExceedsLimit_Revert() public {
        uint256 rateLimit = qeuroToken.mintRateLimit();
        
        // Mint up to the rate limit
        vm.prank(vault);
        qeuroToken.mint(user1, rateLimit);
        
        // Try to mint one more token
        vm.prank(vault);
        vm.expectRevert("QEURO: Mint rate limit exceeded");
        qeuroToken.mint(user2, 1);
    }
    
    /**
     * @notice Test rate limiting for burning within limits
     * @dev Verifies that burning within rate limits works correctly
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
                    vm.warp(block.timestamp + 1 hours);
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
        vm.expectRevert("QEURO: Burn rate limit exceeded");
        qeuroToken.burn(user1, 1);
    }
    
    /**
     * @notice Test rate limit reset after one hour
     * @dev Verifies that rate limits reset after the time period
     */
    function test_RateLimit_ResetAfterOneHour() public {
        uint256 rateLimit = qeuroToken.mintRateLimit();
        
        // Mint up to the rate limit
        vm.prank(vault);
        qeuroToken.mint(user1, rateLimit);
        
        // Advance time by 1 hour
        vm.warp(block.timestamp + 1 hours);
        
        // Now should be able to mint again
        vm.prank(vault);
        qeuroToken.mint(user2, rateLimit);
        
        assertEq(qeuroToken.balanceOf(user2), rateLimit);
    }
    
    /**
     * @notice Test rate limit update by admin
     * @dev Verifies that admin can update rate limits
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
     */
    function test_RateLimit_UpdateByNonAdmin_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.updateRateLimits(1000 * 1e18, 2000 * 1e18);
    }
    
    /**
     * @notice Test rate limit update with invalid values should revert
     * @dev Verifies validation of rate limit parameters
     */
    function test_RateLimit_UpdateInvalidValues_Revert() public {
        // Test zero values
        vm.prank(admin);
        vm.expectRevert("QEURO: Mint limit must be positive");
        qeuroToken.updateRateLimits(0, 1000 * 1e18);
        
        vm.prank(admin);
        vm.expectRevert("QEURO: Burn limit must be positive");
        qeuroToken.updateRateLimits(1000 * 1e18, 0);
        
        // Test values too high
        uint256 tooHigh = 10_000_000 * 1e18 + 1; // MAX_RATE_LIMIT + 1
        vm.prank(admin);
        vm.expectRevert("QEURO: Mint limit too high");
        qeuroToken.updateRateLimits(tooHigh, 1000 * 1e18);
        
        vm.prank(admin);
        vm.expectRevert("QEURO: Burn limit too high");
        qeuroToken.updateRateLimits(1000 * 1e18, tooHigh);
    }

    // =============================================================================
    // COMPLIANCE TESTS
    // =============================================================================
    
    /**
     * @notice Test blacklisting an address
     * @dev Verifies that compliance role can blacklist addresses
     */
    function test_Compliance_BlacklistAddress() public {
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        assertTrue(qeuroToken.isBlacklisted(user1));
    }
    
    /**
     * @notice Test blacklisting by non-compliance role should revert
     * @dev Verifies that only compliance role can blacklist
     */
    function test_Compliance_BlacklistByNonCompliance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.blacklistAddress(user2, "Test blacklist");
    }
    
    /**
     * @notice Test blacklisting zero address should revert
     * @dev Verifies that zero address cannot be blacklisted
     */
    function test_Compliance_BlacklistZeroAddress_Revert() public {
        vm.prank(compliance);
        vm.expectRevert("QEURO: Cannot blacklist zero address");
        qeuroToken.blacklistAddress(address(0), "Test blacklist");
    }
    
    /**
     * @notice Test blacklisting already blacklisted address should revert
     * @dev Verifies that already blacklisted addresses cannot be blacklisted again
     */
    function test_Compliance_BlacklistAlreadyBlacklisted_Revert() public {
        vm.prank(compliance);
        qeuroToken.blacklistAddress(user1, "Test blacklist");
        
        vm.prank(compliance);
        vm.expectRevert("QEURO: Address already blacklisted");
        qeuroToken.blacklistAddress(user1, "Test blacklist again");
    }
    
    /**
     * @notice Test unblacklisting an address
     * @dev Verifies that compliance role can remove addresses from blacklist
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
     */
    function test_Compliance_UnblacklistNonBlacklisted_Revert() public {
        vm.prank(compliance);
        vm.expectRevert("QEURO: Address not blacklisted");
        qeuroToken.unblacklistAddress(user1);
    }
    
    /**
     * @notice Test whitelisting an address
     * @dev Verifies that compliance role can whitelist addresses
     */
    function test_Compliance_WhitelistAddress() public {
        vm.prank(compliance);
        qeuroToken.whitelistAddress(user1);
        
        assertTrue(qeuroToken.isWhitelisted(user1));
    }
    
    /**
     * @notice Test whitelisting by non-compliance role should revert
     * @dev Verifies that only compliance role can whitelist
     */
    function test_Compliance_WhitelistByNonCompliance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.whitelistAddress(user2);
    }
    
    /**
     * @notice Test whitelisting zero address should revert
     * @dev Verifies that zero address cannot be whitelisted
     */
    function test_Compliance_WhitelistZeroAddress_Revert() public {
        vm.prank(compliance);
        vm.expectRevert("QEURO: Cannot whitelist zero address");
        qeuroToken.whitelistAddress(address(0));
    }
    
    /**
     * @notice Test whitelisting already whitelisted address should revert
     * @dev Verifies that already whitelisted addresses cannot be whitelisted again
     */
    function test_Compliance_WhitelistAlreadyWhitelisted_Revert() public {
        vm.prank(compliance);
        qeuroToken.whitelistAddress(user1);
        
        vm.prank(compliance);
        vm.expectRevert("QEURO: Address already whitelisted");
        qeuroToken.whitelistAddress(user1);
    }
    
    /**
     * @notice Test unwhitelisting an address
     * @dev Verifies that compliance role can remove addresses from whitelist
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
     */
    function test_Compliance_UnwhitelistNonWhitelisted_Revert() public {
        vm.prank(compliance);
        vm.expectRevert("QEURO: Address not whitelisted");
        qeuroToken.unwhitelistAddress(user1);
    }
    
    /**
     * @notice Test toggling whitelist mode
     * @dev Verifies that compliance role can toggle whitelist mode
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
     */
    function test_Emergency_Pause() public {
        vm.prank(admin);
        qeuroToken.pause();
        
        assertTrue(qeuroToken.paused());
    }
    
    /**
     * @notice Test pausing by non-pauser role should revert
     * @dev Verifies that only pauser role can pause
     */
    function test_Emergency_PauseByNonPauser_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.pause();
    }
    
    /**
     * @notice Test unpausing the contract
     * @dev Verifies that pauser role can unpause the contract
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
     */
    function test_Admin_UpdateMaxSupplyByNonAdmin_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.updateMaxSupply(200_000_000 * 1e18);
    }
    
    /**
     * @notice Test updating max supply below current supply should revert
     * @dev Verifies that max supply cannot be set below current supply
     */
    function test_Admin_UpdateMaxSupplyBelowCurrent_Revert() public {
        // Mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        // Try to set max supply below current supply
        vm.prank(admin);
        vm.expectRevert("QEURO: New cap below current supply");
        qeuroToken.updateMaxSupply(SMALL_AMOUNT);
    }
    
    /**
     * @notice Test updating max supply to zero should revert
     * @dev Verifies that max supply cannot be set to zero
     */
    function test_Admin_UpdateMaxSupplyToZero_Revert() public {
        vm.prank(admin);
        vm.expectRevert("QEURO: Max supply must be positive");
        qeuroToken.updateMaxSupply(0);
    }
    
    /**
     * @notice Test updating minimum price precision
     * @dev Verifies that admin can update minimum price precision
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
     */
    function test_Admin_UpdateMinPricePrecisionByNonAdmin_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.updateMinPricePrecision(1e6);
    }
    
    /**
     * @notice Test updating min price precision to zero should revert
     * @dev Verifies that minimum price precision cannot be set to zero
     */
    function test_Admin_UpdateMinPricePrecisionToZero_Revert() public {
        vm.prank(admin);
        vm.expectRevert("QEURO: Precision must be positive");
        qeuroToken.updateMinPricePrecision(0);
    }
    
    /**
     * @notice Test updating min price precision too high should revert
     * @dev Verifies that minimum price precision cannot exceed PRECISION
     */
    function test_Admin_UpdateMinPricePrecisionTooHigh_Revert() public {
        vm.prank(admin);
        vm.expectRevert("QEURO: Precision too high");
        qeuroToken.updateMinPricePrecision(1e19); // 1e18 + 1 would be too high
    }

    // =============================================================================
    // UTILITY FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test price normalization with different decimal precisions
     * @dev Verifies that price normalization works correctly for different feed decimals
     */
    function test_Utility_NormalizePrice() public {
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
     */
    function test_Utility_NormalizePriceTooManyDecimals_Revert() public {
        vm.expectRevert("QEURO: Too many decimals");
        qeuroToken.normalizePrice(1000, 19);
    }
    
    /**
     * @notice Test price normalization with zero price should revert
     * @dev Verifies that price normalization fails with zero price
     */
    function test_Utility_NormalizePriceZeroPrice_Revert() public {
        vm.expectRevert("QEURO: Price must be positive");
        qeuroToken.normalizePrice(0, 8);
    }
    
    /**
     * @notice Test price precision validation
     * @dev Verifies that price precision validation works correctly
     */
    function test_Utility_ValidatePricePrecision() public {
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
     * @notice Test remaining mint capacity calculation
     * @dev Verifies that remaining mint capacity is calculated correctly
     */
    function test_Utility_GetRemainingMintCapacity() public {
        uint256 maxSupply = qeuroToken.maxSupply();
        
        // Initially full capacity
        assertEq(qeuroToken.getRemainingMintCapacity(), maxSupply);
        
        // Mint some tokens
        vm.prank(vault);
        qeuroToken.mint(user1, INITIAL_MINT_AMOUNT);
        
        assertEq(qeuroToken.getRemainingMintCapacity(), maxSupply - INITIAL_MINT_AMOUNT);
        
        // Test with a smaller amount to avoid rate limiting issues
        // This test focuses on the calculation logic, not the full supply scenario
    }
    
    /**
     * @notice Test rate limit status
     * @dev Verifies that rate limit status returns correct information
     */
    function test_Utility_GetRateLimitStatus() public {
        (
            uint256 mintedThisHour,
            uint256 burnedThisHour,
            uint256 mintLimit,
            uint256 burnLimit,
            uint256 nextResetTime
        ) = qeuroToken.getRateLimitStatus();
        
        assertEq(mintedThisHour, 0);
        assertEq(burnedThisHour, 0);
        assertEq(mintLimit, qeuroToken.mintRateLimit());
        assertEq(burnLimit, qeuroToken.burnRateLimit());
        assertEq(nextResetTime, qeuroToken.lastRateLimitReset() + 1 hours);
        
        // Mint some tokens and check again
        vm.prank(vault);
        qeuroToken.mint(user1, SMALL_AMOUNT);
        
        (mintedThisHour, , , , ) = qeuroToken.getRateLimitStatus();
        assertEq(mintedThisHour, SMALL_AMOUNT);
    }
    
    /**
     * @notice Test token info retrieval
     * @dev Verifies that complete token information is returned correctly
     */
    function test_Utility_GetTokenInfo() public {
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
     * @notice Test recovering external tokens
     * @dev Verifies that admin can recover accidentally sent tokens
     */
    function test_Recovery_RecoverToken() public {
        // Create a mock ERC20 token
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");
        mockToken.mint(address(qeuroToken), 1000);
        
        uint256 initialBalance = mockToken.balanceOf(user1);
        
        vm.prank(admin);
        qeuroToken.recoverToken(address(mockToken), user1, 500);
        
        assertEq(mockToken.balanceOf(user1), initialBalance + 500);
    }
    
    /**
     * @notice Test recovering QEURO tokens should revert
     * @dev Verifies that QEURO tokens cannot be recovered
     */
    function test_Recovery_RecoverQEURO_Revert() public {
        vm.prank(admin);
        vm.expectRevert("QEURO: Cannot recover QEURO tokens");
        qeuroToken.recoverToken(address(qeuroToken), user1, 1000);
    }
    
    /**
     * @notice Test recovering tokens by non-admin should revert
     * @dev Verifies that only admin can recover tokens
     */
    function test_Recovery_RecoverTokenByNonAdmin_Revert() public {
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");
        
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.recoverToken(address(mockToken), user2, 1000);
    }
    
    /**
     * @notice Test recovering ETH
     * @dev Verifies that admin can recover accidentally sent ETH
     */
    function test_Recovery_RecoverETH() public {
        // Send ETH to the contract
        vm.deal(address(qeuroToken), 1 ether);
        
        uint256 initialBalance = user1.balance;
        
        vm.prank(admin);
        qeuroToken.recoverETH(payable(user1));
        
        assertEq(user1.balance, initialBalance + 1 ether);
    }
    
    /**
     * @notice Test recovering ETH by non-admin should revert
     * @dev Verifies that only admin can recover ETH
     */
    function test_Recovery_RecoverETHByNonAdmin_Revert() public {
        vm.deal(address(qeuroToken), 1 ether);
        
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.recoverETH(payable(user2));
    }

    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test complete mint-burn cycle
     * @dev Verifies that a complete mint and burn cycle works correctly
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
        vm.expectRevert("QEURO: Recipient is blacklisted");
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
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
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
