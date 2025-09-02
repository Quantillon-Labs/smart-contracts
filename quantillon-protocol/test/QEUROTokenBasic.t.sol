// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title QEUROTokenBasicTest
 * @notice Basic test suite for QEUROToken using proxy pattern
 * @custom:security-contact team@quantillon.money
 */
contract QEUROTokenBasicTest is Test {
    QEUROToken public implementation;
    QEUROToken public qeuroToken;
    
    address public admin = address(0x1);
    address public vault = address(0x2);
    address public user1 = address(0x3);
    
    function setUp() public {
        // Deploy implementation
        implementation = new QEUROToken();
        
        // Create mock timelock address
        address mockTimelock = address(0x123);
        
        // Deploy proxy
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
    }
    
    /**
     * @notice Test successful contract initialization
     * @dev Verifies proper initialization with valid parameters
     */
    function testInitialization_WithValidParameters_ShouldInitializeCorrectly() public view {
        assertEq(qeuroToken.name(), "Quantillon Euro");
        assertEq(qeuroToken.symbol(), "QEURO");
        assertEq(qeuroToken.decimals(), 18);
        assertEq(qeuroToken.totalSupply(), 0);
    }
    
    /**
     * @notice Test token minting with valid parameters
     * @dev Verifies that tokens can be minted successfully
     */
    function testMint_WithValidParameters_ShouldMintTokens() public {
        vm.prank(vault);
        qeuroToken.mint(user1, 1000 * 1e18);
        
        assertEq(qeuroToken.balanceOf(user1), 1000 * 1e18);
        assertEq(qeuroToken.totalSupply(), 1000 * 1e18);
    }
}
