// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ErrorLibrary} from "../src/libraries/ErrorLibrary.sol";
import {FeeCollector} from "../src/core/FeeCollector.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/**
 * @title FeeCollectorTest
 * @notice Comprehensive test suite for FeeCollector contract
 * 
 * @dev Tests all functionalities of the FeeCollector contract:
 *      - Initialization and role management
 *      - Fee collection from authorized sources
 *      - Fee distribution according to configured ratios
 *      - Governance functions (ratio updates, address updates)
 *      - Emergency functions (pause, emergency withdrawal)
 *      - View functions and statistics
 *      - Access control and security
 *      - Edge cases and error conditions
 * 
 * @author Quantillon Protocol Team
 * @custom:security-contact team@quantillon.money
 */
contract FeeCollectorTest is Test {
    // =============================================================================
    // CONTRACTS AND ADDRESSES
    // =============================================================================
    
    FeeCollector public feeCollector;
    FeeCollector public feeCollectorImpl;
    MockUSDC public mockUSDC;
    
    address public admin;
    address public treasury;
    address public devFund;
    address public communityFund;
    address public unauthorizedUser;
    address public feeSource;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event FeesCollected(address indexed token, uint256 amount, address indexed source, string indexed sourceType);
    event FeesDistributed(address indexed token, uint256 totalAmount, uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount);
    event FeeRatiosUpdated(uint256 treasuryRatio, uint256 devFundRatio, uint256 communityRatio);
    event FundAddressesUpdated(address treasury, address devFund, address communityFund);
    
    // =============================================================================
    // SETUP
    // =============================================================================
    
    function setUp() public {
        // Set up addresses
        admin = address(0x1);
        treasury = address(0x2);
        devFund = address(0x3);
        communityFund = address(0x4);
        unauthorizedUser = address(0x5);
        feeSource = address(0x6);
        
        // Deploy mock USDC
        mockUSDC = new MockUSDC();
        
        // Deploy FeeCollector implementation
        feeCollectorImpl = new FeeCollector();
        
        // Deploy FeeCollector proxy
        bytes memory initData = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury,
            devFund,
            communityFund
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(feeCollectorImpl), initData);
        feeCollector = FeeCollector(address(proxy));
        
        // Set up roles
        vm.startPrank(admin);
        feeCollector.authorizeFeeSource(feeSource);
        feeCollector.authorizeFeeSource(admin); // Admin should also be authorized
        vm.stopPrank();
        
        // Mint USDC to test addresses
        mockUSDC.mint(admin, 1000000e6);
        mockUSDC.mint(feeSource, 1000000e6);
        mockUSDC.mint(unauthorizedUser, 1000000e6);
    }
    
    // =============================================================================
    // INITIALIZATION TESTS
    // =============================================================================
    
    /**
     * @notice Test successful initialization
     * @dev Verifies that the contract initializes with correct parameters
     */
    function test_Initialization_Success() public {
        assertEq(feeCollector.treasury(), treasury);
        assertEq(feeCollector.devFund(), devFund);
        assertEq(feeCollector.communityFund(), communityFund);
        assertEq(feeCollector.treasuryRatio(), 6000);
        assertEq(feeCollector.devFundRatio(), 2500);
        assertEq(feeCollector.communityRatio(), 1500);
        assertTrue(feeCollector.hasRole(feeCollector.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(feeCollector.hasRole(feeCollector.GOVERNANCE_ROLE(), admin));
        assertTrue(feeCollector.hasRole(feeCollector.TREASURY_ROLE(), treasury));
        assertTrue(feeCollector.hasRole(feeCollector.EMERGENCY_ROLE(), admin));
    }
    
    /**
     * @notice Test initialization with zero addresses
     * @dev Verifies that initialization fails with zero addresses
     */
    function test_Initialization_ZeroAddresses() public {
        FeeCollector newImpl = new FeeCollector();
        
        // Test zero admin
        vm.expectRevert(ErrorLibrary.ZeroAddress.selector);
        bytes memory initData1 = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            address(0),
            treasury,
            devFund,
            communityFund
        );
        new ERC1967Proxy(address(newImpl), initData1);
        
        // Test zero treasury
        vm.expectRevert(ErrorLibrary.ZeroAddress.selector);
        bytes memory initData2 = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            address(0),
            devFund,
            communityFund
        );
        new ERC1967Proxy(address(newImpl), initData2);
        
        // Test zero devFund
        vm.expectRevert(ErrorLibrary.ZeroAddress.selector);
        bytes memory initData3 = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury,
            address(0),
            communityFund
        );
        new ERC1967Proxy(address(newImpl), initData3);
        
        // Test zero communityFund
        vm.expectRevert(ErrorLibrary.ZeroAddress.selector);
        bytes memory initData4 = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury,
            devFund,
            address(0)
        );
        new ERC1967Proxy(address(newImpl), initData4);
    }
    
    // =============================================================================
    // FEE COLLECTION TESTS
    // =============================================================================
    
    /**
     * @notice Test successful fee collection from authorized source
     * @dev Verifies that authorized sources can collect fees
     */
    function test_CollectFees_Success() public {
        uint256 feeAmount = 1000e6;
        
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), feeAmount);
        
        vm.expectEmit(true, true, true, true);
        emit FeesCollected(address(mockUSDC), feeAmount, feeSource, "minting");
        feeCollector.collectFees(address(mockUSDC), feeAmount, "minting");
        vm.stopPrank();
        
        assertEq(mockUSDC.balanceOf(address(feeCollector)), feeAmount);
        assertEq(feeCollector.totalFeesCollected(address(mockUSDC)), feeAmount);
        assertEq(feeCollector.feeCollectionCount(address(mockUSDC)), 1);
    }
    
    /**
     * @notice Test fee collection from unauthorized source
     * @dev Verifies that unauthorized sources cannot collect fees
     */
    function test_CollectFees_UnauthorizedSource() public {
        uint256 feeAmount = 1000e6;
        
        vm.startPrank(unauthorizedUser);
        mockUSDC.approve(address(feeCollector), feeAmount);
        
        vm.expectRevert("FeeCollector: Unauthorized fee source");
        feeCollector.collectFees(address(mockUSDC), feeAmount, "minting");
        vm.stopPrank();
    }
    
    /**
     * @notice Test fee collection with zero amount
     * @dev Verifies that zero amount collection fails
     */
    function test_CollectFees_ZeroAmount() public {
        vm.startPrank(feeSource);
        vm.expectRevert(ErrorLibrary.InvalidAmount.selector);
        feeCollector.collectFees(address(mockUSDC), 0, "minting");
        vm.stopPrank();
    }
    
    /**
     * @notice Test fee collection with zero token address
     * @dev Verifies that zero token address collection fails
     */
    function test_CollectFees_ZeroTokenAddress() public {
        vm.startPrank(feeSource);
        vm.expectRevert(ErrorLibrary.ZeroAddress.selector);
        feeCollector.collectFees(address(0), 1000e6, "minting");
        vm.stopPrank();
    }
    
    /**
     * @notice Test ETH fee collection
     * @dev Verifies that ETH fees can be collected
     */
    function test_CollectETHFees_Success() public {
        uint256 ethAmount = 1 ether;
        
        // Fund the fee source with ETH
        vm.deal(feeSource, ethAmount);
        
        vm.startPrank(feeSource);
        vm.expectEmit(true, true, true, true);
        emit FeesCollected(address(0), ethAmount, feeSource, "staking");
        feeCollector.collectETHFees{value: ethAmount}("staking");
        vm.stopPrank();
        
        assertEq(address(feeCollector).balance, ethAmount);
        assertEq(feeCollector.totalFeesCollected(address(0)), ethAmount);
        assertEq(feeCollector.feeCollectionCount(address(0)), 1);
    }
    
    /**
     * @notice Test multiple fee collections
     * @dev Verifies that multiple fee collections accumulate correctly
     */
    function test_CollectFees_MultipleCollections() public {
        uint256 feeAmount1 = 1000e6;
        uint256 feeAmount2 = 2000e6;
        
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), feeAmount1 + feeAmount2);
        
        feeCollector.collectFees(address(mockUSDC), feeAmount1, "minting");
        feeCollector.collectFees(address(mockUSDC), feeAmount2, "redemption");
        vm.stopPrank();
        
        assertEq(mockUSDC.balanceOf(address(feeCollector)), feeAmount1 + feeAmount2);
        assertEq(feeCollector.totalFeesCollected(address(mockUSDC)), feeAmount1 + feeAmount2);
        assertEq(feeCollector.feeCollectionCount(address(mockUSDC)), 2);
    }
    
    // =============================================================================
    // FEE DISTRIBUTION TESTS
    // =============================================================================
    
    /**
     * @notice Test successful fee distribution
     * @dev Verifies that fees are distributed according to configured ratios
     */
    function test_DistributeFees_Success() public {
        uint256 totalFees = 10000e6;
        
        // Collect fees first
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), totalFees);
        feeCollector.collectFees(address(mockUSDC), totalFees, "minting");
        vm.stopPrank();
        
        // Record balances before distribution
        uint256 treasuryBalanceBefore = mockUSDC.balanceOf(treasury);
        uint256 devFundBalanceBefore = mockUSDC.balanceOf(devFund);
        uint256 communityBalanceBefore = mockUSDC.balanceOf(communityFund);
        
        // Distribute fees
        vm.startPrank(treasury);
        vm.expectEmit(true, true, true, true);
        emit FeesDistributed(address(mockUSDC), totalFees, 6000e6, 2500e6, 1500e6);
        feeCollector.distributeFees(address(mockUSDC));
        vm.stopPrank();
        
        // Verify distribution
        assertEq(mockUSDC.balanceOf(treasury), treasuryBalanceBefore + 6000e6);
        assertEq(mockUSDC.balanceOf(devFund), devFundBalanceBefore + 2500e6);
        assertEq(mockUSDC.balanceOf(communityFund), communityBalanceBefore + 1500e6);
        assertEq(feeCollector.totalFeesDistributed(address(mockUSDC)), totalFees);
        assertEq(mockUSDC.balanceOf(address(feeCollector)), 0);
    }
    
    /**
     * @notice Test fee distribution with zero balance
     * @dev Verifies that distribution fails with zero balance
     */
    function test_DistributeFees_ZeroBalance() public {
        vm.startPrank(treasury);
        vm.expectRevert(ErrorLibrary.InsufficientBalance.selector);
        feeCollector.distributeFees(address(mockUSDC));
        vm.stopPrank();
    }
    
    /**
     * @notice Test fee distribution by unauthorized user
     * @dev Verifies that only treasury role can distribute fees
     */
    function test_DistributeFees_UnauthorizedUser() public {
        uint256 totalFees = 10000e6;
        
        // Collect fees first
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), totalFees);
        feeCollector.collectFees(address(mockUSDC), totalFees, "minting");
        vm.stopPrank();
        
        // Try to distribute from unauthorized address
        vm.startPrank(unauthorizedUser);
        vm.expectRevert();
        feeCollector.distributeFees(address(mockUSDC));
        vm.stopPrank();
    }
    
    /**
     * @notice Test ETH fee distribution
     * @dev Verifies that ETH fees can be distributed
     */
    function test_DistributeETHFees_Success() public {
        uint256 totalFees = 1 ether;
        
        // Fund the fee source with ETH
        vm.deal(feeSource, totalFees);
        
        // Collect ETH fees first
        vm.startPrank(feeSource);
        feeCollector.collectETHFees{value: totalFees}("staking");
        vm.stopPrank();
        
        // Record balances before distribution
        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 devFundBalanceBefore = devFund.balance;
        uint256 communityBalanceBefore = communityFund.balance;
        
        // Distribute ETH fees
        vm.startPrank(treasury);
        feeCollector.distributeFees(address(0));
        vm.stopPrank();
        
        // Verify distribution
        assertEq(treasury.balance, treasuryBalanceBefore + 0.6 ether);
        assertEq(devFund.balance, devFundBalanceBefore + 0.25 ether);
        assertEq(communityFund.balance, communityBalanceBefore + 0.15 ether);
        assertEq(address(feeCollector).balance, 0);
    }
    
    // =============================================================================
    // GOVERNANCE TESTS
    // =============================================================================
    
    /**
     * @notice Test fee ratio updates
     * @dev Verifies that governance can update fee distribution ratios
     */
    function test_UpdateFeeRatios_Success() public {
        uint256 newTreasuryRatio = 5000;
        uint256 newDevFundRatio = 3000;
        uint256 newCommunityRatio = 2000;
        
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit FeeRatiosUpdated(newTreasuryRatio, newDevFundRatio, newCommunityRatio);
        feeCollector.updateFeeRatios(newTreasuryRatio, newDevFundRatio, newCommunityRatio);
        vm.stopPrank();
        
        assertEq(feeCollector.treasuryRatio(), newTreasuryRatio);
        assertEq(feeCollector.devFundRatio(), newDevFundRatio);
        assertEq(feeCollector.communityRatio(), newCommunityRatio);
    }
    
    /**
     * @notice Test fee ratio updates with invalid ratios
     * @dev Verifies that ratios must sum to 10000 (100%)
     */
    function test_UpdateFeeRatios_InvalidRatios() public {
        vm.startPrank(admin);
        vm.expectRevert(ErrorLibrary.InvalidRatio.selector);
        feeCollector.updateFeeRatios(5000, 3000, 1000); // Sums to 9000, not 10000
        vm.stopPrank();
    }
    
    /**
     * @notice Test fee ratio updates by unauthorized user
     * @dev Verifies that only governance can update ratios
     */
    function test_UpdateFeeRatios_UnauthorizedUser() public {
        vm.startPrank(unauthorizedUser);
        vm.expectRevert();
        feeCollector.updateFeeRatios(5000, 3000, 2000);
        vm.stopPrank();
    }
    
    /**
     * @notice Test fund address updates
     * @dev Verifies that governance can update fund addresses
     */
    function test_UpdateFundAddresses_Success() public {
        address newTreasury = address(0x10);
        address newDevFund = address(0x11);
        address newCommunityFund = address(0x12);
        
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit FundAddressesUpdated(newTreasury, newDevFund, newCommunityFund);
        feeCollector.updateFundAddresses(newTreasury, newDevFund, newCommunityFund);
        vm.stopPrank();
        
        assertEq(feeCollector.treasury(), newTreasury);
        assertEq(feeCollector.devFund(), newDevFund);
        assertEq(feeCollector.communityFund(), newCommunityFund);
    }
    
    /**
     * @notice Test fund address updates with zero addresses
     * @dev Verifies that zero addresses are rejected
     */
    function test_UpdateFundAddresses_ZeroAddresses() public {
        vm.startPrank(admin);
        vm.expectRevert(ErrorLibrary.ZeroAddress.selector);
        feeCollector.updateFundAddresses(address(0), devFund, communityFund);
        vm.stopPrank();
    }
    
    /**
     * @notice Test fee source authorization
     * @dev Verifies that governance can authorize fee sources
     */
    function test_AuthorizeFeeSource_Success() public {
        address newFeeSource = address(0x20);
        
        vm.startPrank(admin);
        feeCollector.authorizeFeeSource(newFeeSource);
        vm.stopPrank();
        
        assertTrue(feeCollector.hasRole(feeCollector.TREASURY_ROLE(), newFeeSource));
        assertTrue(feeCollector.isAuthorizedFeeSource(newFeeSource));
    }
    
    /**
     * @notice Test fee source revocation
     * @dev Verifies that governance can revoke fee source authorization
     */
    function test_RevokeFeeSource_Success() public {
        vm.startPrank(admin);
        feeCollector.revokeFeeSource(feeSource);
        vm.stopPrank();
        
        assertFalse(feeCollector.hasRole(feeCollector.TREASURY_ROLE(), feeSource));
        assertFalse(feeCollector.isAuthorizedFeeSource(feeSource));
    }
    
    // =============================================================================
    // EMERGENCY TESTS
    // =============================================================================
    
    /**
     * @notice Test pause functionality
     * @dev Verifies that emergency role can pause the contract
     */
    function test_Pause_Success() public {
        vm.startPrank(admin);
        feeCollector.pause();
        vm.stopPrank();
        
        assertTrue(feeCollector.paused());
    }
    
    /**
     * @notice Test unpause functionality
     * @dev Verifies that emergency role can unpause the contract
     */
    function test_Unpause_Success() public {
        // Pause first
        vm.startPrank(admin);
        feeCollector.pause();
        feeCollector.unpause();
        vm.stopPrank();
        
        assertFalse(feeCollector.paused());
    }
    
    /**
     * @notice Test fee collection when paused
     * @dev Verifies that fee collection is blocked when paused
     */
    function test_CollectFees_WhenPaused() public {
        vm.startPrank(admin);
        feeCollector.pause();
        vm.stopPrank();
        
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), 1000e6);
        vm.expectRevert();
        feeCollector.collectFees(address(mockUSDC), 1000e6, "minting");
        vm.stopPrank();
    }
    
    /**
     * @notice Test emergency withdrawal
     * @dev Verifies that emergency role can withdraw all tokens
     */
    function test_EmergencyWithdraw_Success() public {
        uint256 totalFees = 10000e6;
        
        // Collect fees first
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), totalFees);
        feeCollector.collectFees(address(mockUSDC), totalFees, "minting");
        vm.stopPrank();
        
        uint256 treasuryBalanceBefore = mockUSDC.balanceOf(treasury);
        
        // Emergency withdraw
        vm.startPrank(admin);
        feeCollector.emergencyWithdraw(address(mockUSDC));
        vm.stopPrank();
        
        assertEq(mockUSDC.balanceOf(treasury), treasuryBalanceBefore + totalFees);
        assertEq(mockUSDC.balanceOf(address(feeCollector)), 0);
    }
    
    /**
     * @notice Test emergency withdrawal with zero balance
     * @dev Verifies that emergency withdrawal fails with zero balance
     */
    function test_EmergencyWithdraw_ZeroBalance() public {
        vm.startPrank(admin);
        vm.expectRevert(ErrorLibrary.InsufficientBalance.selector);
        feeCollector.emergencyWithdraw(address(mockUSDC));
        vm.stopPrank();
    }
    
    // =============================================================================
    // VIEW FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test getBalance function
     * @dev Verifies that getBalance returns correct token balance
     */
    function test_GetBalance_Success() public {
        uint256 feeAmount = 1000e6;
        
        // Collect fees
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), feeAmount);
        feeCollector.collectFees(address(mockUSDC), feeAmount, "minting");
        vm.stopPrank();
        
        assertEq(feeCollector.getBalance(address(mockUSDC)), feeAmount);
    }
    
    /**
     * @notice Test getFeeStats function
     * @dev Verifies that getFeeStats returns correct statistics
     */
    function test_GetFeeStats_Success() public {
        uint256 feeAmount = 1000e6;
        
        // Collect fees
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), feeAmount);
        feeCollector.collectFees(address(mockUSDC), feeAmount, "minting");
        vm.stopPrank();
        
        (uint256 totalCollected, uint256 totalDistributed, uint256 collectionCount, uint256 currentBalance) = 
            feeCollector.getFeeStats(address(mockUSDC));
        
        assertEq(totalCollected, feeAmount);
        assertEq(totalDistributed, 0);
        assertEq(collectionCount, 1);
        assertEq(currentBalance, feeAmount);
    }
    
    /**
     * @notice Test isAuthorizedFeeSource function
     * @dev Verifies that isAuthorizedFeeSource returns correct authorization status
     */
    function test_IsAuthorizedFeeSource_Success() public {
        assertTrue(feeCollector.isAuthorizedFeeSource(feeSource));
        assertTrue(feeCollector.isAuthorizedFeeSource(treasury));
        assertTrue(feeCollector.isAuthorizedFeeSource(admin));
        assertFalse(feeCollector.isAuthorizedFeeSource(unauthorizedUser));
    }
    
    // =============================================================================
    // EDGE CASE TESTS
    // =============================================================================
    
    /**
     * @notice Test fee distribution with rounding
     * @dev Verifies that fee distribution handles rounding correctly
     */
    function test_DistributeFees_Rounding() public {
        uint256 totalFees = 10001e6; // Odd number to test rounding
        
        // Collect fees first
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), totalFees);
        feeCollector.collectFees(address(mockUSDC), totalFees, "minting");
        vm.stopPrank();
        
        // Distribute fees
        vm.startPrank(treasury);
        feeCollector.distributeFees(address(mockUSDC));
        vm.stopPrank();
        
        // Verify that total distributed doesn't exceed balance
        uint256 totalDistributed = mockUSDC.balanceOf(treasury) + 
                                  mockUSDC.balanceOf(devFund) + 
                                  mockUSDC.balanceOf(communityFund);
        assertLe(totalDistributed, totalFees);
        assertEq(mockUSDC.balanceOf(address(feeCollector)), 0);
    }
    
    /**
     * @notice Test multiple token fee collection
     * @dev Verifies that different tokens are tracked separately
     */
    function test_MultipleTokenFeeCollection() public {
        // Deploy another mock token
        MockUSDC mockToken2 = new MockUSDC();
        mockToken2.mint(feeSource, 1000000e6);
        
        uint256 feeAmount1 = 1000e6;
        uint256 feeAmount2 = 2000e6;
        
        vm.startPrank(feeSource);
        mockUSDC.approve(address(feeCollector), feeAmount1);
        mockToken2.approve(address(feeCollector), feeAmount2);
        
        feeCollector.collectFees(address(mockUSDC), feeAmount1, "minting");
        feeCollector.collectFees(address(mockToken2), feeAmount2, "redemption");
        vm.stopPrank();
        
        // Verify separate tracking
        assertEq(feeCollector.totalFeesCollected(address(mockUSDC)), feeAmount1);
        assertEq(feeCollector.totalFeesCollected(address(mockToken2)), feeAmount2);
        assertEq(feeCollector.feeCollectionCount(address(mockUSDC)), 1);
        assertEq(feeCollector.feeCollectionCount(address(mockToken2)), 1);
    }
    
    /**
     * @notice Test upgrade authorization
     * @dev Verifies that only governance can authorize upgrades
     */
    function test_UpgradeAuthorization() public {
        FeeCollector newImpl = new FeeCollector();
        
        // Admin can upgrade
        vm.startPrank(admin);
        feeCollector.upgradeToAndCall(address(newImpl), "");
        vm.stopPrank();
        
        // Unauthorized user cannot upgrade
        vm.startPrank(unauthorizedUser);
        vm.expectRevert();
        feeCollector.upgradeToAndCall(address(newImpl), "");
        vm.stopPrank();
    }
}
