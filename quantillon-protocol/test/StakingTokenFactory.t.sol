// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StakingTokenFactory} from "../src/core/StakingTokenFactory.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {StakingTokenFactoryErrorLibrary} from "../src/libraries/StakingTokenFactoryErrorLibrary.sol";

/**
 * @title StakingTokenFactoryTestSuite
 * @notice Comprehensive test suite for the StakingTokenFactory contract
 *
 * @dev Test categories:
 *      - Initialization
 *      - createStakingToken (success, duplicates, access control)
 *      - Registry view functions
 *      - updateImplementation governance
 *      - Pause / unpause emergency
 *      - Token independence (stake in vault 1 does not pollute vault 2)
 *      - Fuzz: creation of N tokens with varied vault IDs
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract StakingTokenFactoryTestSuite is Test {
    // =============================================================================
    // CONTRACTS
    // =============================================================================

    StakingTokenFactory public factory;
    stQEUROToken public stQEUROImpl;
    TimeProvider public timeProvider;

    // =============================================================================
    // TEST ADDRESSES
    // =============================================================================

    address public admin = address(0x10);
    address public governance = address(0x11);
    address public factoryOperator = address(0x12);
    address public treasury = address(0x20);
    address public mockTimelock = address(0x30);
    address public mockQEURO = address(0x40);
    address public mockYieldShift = address(0x50);
    address public mockUSDC = address(0x60);

    address public vault1 = address(0x101);
    address public vault2 = address(0x102);
    address public vault3 = address(0x103);

    address public attacker = address(0xDEAD);

    // =============================================================================
    // CONSTANTS
    // =============================================================================

    uint256 public constant VAULT_ID_1 = 1;
    uint256 public constant VAULT_ID_2 = 2;
    uint256 public constant VAULT_ID_3 = 3;

    // =============================================================================
    // EVENTS FOR TESTING
    // =============================================================================

    event StakingTokenCreated(
        uint256 indexed vaultId,
        address indexed stakingToken,
        address indexed vault,
        string name,
        string symbol
    );
    event ImplementationUpdated(address indexed oldImpl, address indexed newImpl);

    // =============================================================================
    // SETUP
    // =============================================================================

    function setUp() public {
        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));

        // Deploy stQEUROToken implementation (not a proxy — just the logic contract)
        stQEUROImpl = new stQEUROToken(timeProvider);

        // Deploy StakingTokenFactory via proxy
        StakingTokenFactory factoryImpl = new StakingTokenFactory(timeProvider);
        bytes memory factoryInitData = abi.encodeWithSelector(
            StakingTokenFactory.initialize.selector,
            admin,
            address(stQEUROImpl),
            mockTimelock
        );
        ERC1967Proxy factoryProxy = new ERC1967Proxy(address(factoryImpl), factoryInitData);
        factory = StakingTokenFactory(address(factoryProxy));

        // Grant roles for testing
        vm.prank(admin);
        factory.grantRole(keccak256("GOVERNANCE_ROLE"), governance);
        vm.prank(admin);
        factory.grantRole(keccak256("FACTORY_ROLE"), factoryOperator);
    }

    // =============================================================================
    // HELPER
    // =============================================================================

    /// @dev Creates a staking token with default mock parameters for the given vault
    function _createToken(uint256 vaultId, address vault, string memory name, string memory symbol)
        internal
        returns (address proxy)
    {
        vm.prank(admin);
        proxy = factory.createStakingToken(
            vaultId,
            vault,
            name,
            symbol,
            admin,
            mockQEURO,
            mockYieldShift,
            mockUSDC,
            treasury,
            mockTimelock
        );
    }

    // =============================================================================
    // INITIALIZATION TESTS
    // =============================================================================

    /**
     * @notice Test factory initializes correctly
     */
    function test_Initialize_Success() public view {
        assertEq(factory.stakingTokenImplementation(), address(stQEUROImpl));
        assertEq(factory.tokenCount(), 0);
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(keccak256("FACTORY_ROLE"), admin));
        assertTrue(factory.hasRole(keccak256("GOVERNANCE_ROLE"), admin));
        assertTrue(factory.hasRole(keccak256("EMERGENCY_ROLE"), admin));
    }

    /**
     * @notice Test initialize reverts with zero admin
     */
    function test_Initialize_ZeroAdmin_Reverts() public {
        StakingTokenFactory impl2 = new StakingTokenFactory(timeProvider);
        bytes memory badInit = abi.encodeWithSelector(
            StakingTokenFactory.initialize.selector,
            address(0),
            address(stQEUROImpl),
            mockTimelock
        );
        vm.expectRevert(CommonErrorLibrary.InvalidAdmin.selector);
        new ERC1967Proxy(address(impl2), badInit);
    }

    /**
     * @notice Test initialize reverts with zero implementation
     */
    function test_Initialize_ZeroImpl_Reverts() public {
        StakingTokenFactory impl2 = new StakingTokenFactory(timeProvider);
        bytes memory badInit = abi.encodeWithSelector(
            StakingTokenFactory.initialize.selector,
            admin,
            address(0),
            mockTimelock
        );
        vm.expectRevert(StakingTokenFactoryErrorLibrary.InvalidImplementation.selector);
        new ERC1967Proxy(address(impl2), badInit);
    }

    // =============================================================================
    // createStakingToken — SUCCESS
    // =============================================================================

    /**
     * @notice Test successful creation of a single staking token
     */
    function test_CreateStakingToken_Success() public {
        vm.expectEmit(false, false, true, false);
        emit StakingTokenCreated(VAULT_ID_1, address(0), vault1, "Staked QEURO Vault 1", "stQEURO1");

        address proxy = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");

        assertFalse(proxy == address(0), "proxy should not be zero");
        assertEq(factory.stakingTokens(VAULT_ID_1), proxy);
        assertEq(factory.tokenCount(), 1);
    }

    /**
     * @notice Test ERC20 metadata is correctly set on newly created token
     */
    function test_CreateStakingToken_ERC20Metadata() public {
        address proxy = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");

        stQEUROToken token = stQEUROToken(proxy);
        assertEq(token.name(), "Staked QEURO Vault 1");
        assertEq(token.symbol(), "stQEURO1");
        assertEq(token.vaultId(), VAULT_ID_1);
        assertEq(token.associatedVault(), vault1);
    }

    /**
     * @notice Test creation of multiple staking tokens for different vaults
     */
    function test_CreateStakingToken_MultipleVaults() public {
        address proxy1 = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        address proxy2 = _createToken(VAULT_ID_2, vault2, "Staked QEURO Vault 2", "stQEURO2");
        address proxy3 = _createToken(VAULT_ID_3, vault3, "Staked QEURO Vault 3", "stQEURO3");

        assertEq(factory.tokenCount(), 3);
        assertEq(factory.stakingTokens(VAULT_ID_1), proxy1);
        assertEq(factory.stakingTokens(VAULT_ID_2), proxy2);
        assertEq(factory.stakingTokens(VAULT_ID_3), proxy3);

        // Each proxy has correct metadata
        assertEq(stQEUROToken(proxy1).symbol(), "stQEURO1");
        assertEq(stQEUROToken(proxy2).symbol(), "stQEURO2");
        assertEq(stQEUROToken(proxy3).symbol(), "stQEURO3");
    }

    /**
     * @notice Test vaultId 0 is supported
     */
    function test_CreateStakingToken_VaultIdZero() public {
        address proxy = _createToken(0, vault1, "Staked QEURO Vault 0", "stQEURO0");
        assertEq(factory.stakingTokens(0), proxy);
        assertEq(stQEUROToken(proxy).vaultId(), 0);
    }

    /**
     * @notice Test factory operator role can also create tokens
     */
    function test_CreateStakingToken_FactoryRole() public {
        vm.prank(factoryOperator);
        address proxy = factory.createStakingToken(
            VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1",
            admin, mockQEURO, mockYieldShift, mockUSDC, treasury, mockTimelock
        );
        assertFalse(proxy == address(0));
    }

    // =============================================================================
    // createStakingToken — REVERTS
    // =============================================================================

    /**
     * @notice Test revert when vault ID already exists
     */
    function test_CreateStakingToken_DuplicateVaultId_Reverts() public {
        _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");

        vm.expectRevert(
            abi.encodeWithSelector(StakingTokenFactoryErrorLibrary.StakingTokenAlreadyExists.selector, VAULT_ID_1)
        );
        _createToken(VAULT_ID_1, vault2, "Staked QEURO Vault 1 Dup", "stQEURO1dup");
    }

    /**
     * @notice Test revert when vault address already registered
     */
    function test_CreateStakingToken_DuplicateVaultAddress_Reverts() public {
        _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");

        vm.expectRevert(
            abi.encodeWithSelector(StakingTokenFactoryErrorLibrary.VaultAlreadyRegistered.selector, vault1)
        );
        _createToken(VAULT_ID_2, vault1, "Staked QEURO Vault 2", "stQEURO2");
    }

    /**
     * @notice Test revert when caller lacks FACTORY_ROLE
     */
    function test_CreateStakingToken_NotFactoryRole_Reverts() public {
        vm.expectRevert();
        vm.prank(attacker);
        factory.createStakingToken(
            VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1",
            admin, mockQEURO, mockYieldShift, mockUSDC, treasury, mockTimelock
        );
    }

    /**
     * @notice Test revert when vault address is zero
     */
    function test_CreateStakingToken_ZeroVault_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidVault.selector);
        _createToken(VAULT_ID_1, address(0), "Staked QEURO Vault 1", "stQEURO1");
    }

    /**
     * @notice Test revert when paused
     */
    function test_CreateStakingToken_WhenPaused_Reverts() public {
        vm.prank(admin);
        factory.pause();

        vm.expectRevert();
        _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Test getStakingToken returns correct address
     */
    function test_GetStakingToken_Success() public {
        address proxy = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        assertEq(factory.getStakingToken(VAULT_ID_1), proxy);
    }

    /**
     * @notice Test getStakingToken reverts for unregistered vault ID
     */
    function test_GetStakingToken_NotFound_Reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(StakingTokenFactoryErrorLibrary.StakingTokenNotFound.selector, 999)
        );
        factory.getStakingToken(999);
    }

    /**
     * @notice Test getStakingTokenByVault returns correct address
     */
    function test_GetStakingTokenByVault_Success() public {
        address proxy = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        assertEq(factory.getStakingTokenByVault(vault1), proxy);
    }

    /**
     * @notice Test getStakingTokenByVault returns address(0) for unknown vault
     */
    function test_GetStakingTokenByVault_NotFound_ReturnsZero() public view {
        assertEq(factory.getStakingTokenByVault(vault1), address(0));
    }

    /**
     * @notice Test isVaultRegistered returns correct values
     */
    function test_IsVaultRegistered() public {
        assertFalse(factory.isVaultRegistered(vault1));
        _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        assertTrue(factory.isVaultRegistered(vault1));
        assertFalse(factory.isVaultRegistered(vault2));
    }

    /**
     * @notice Test getAllVaultIds returns IDs in creation order
     */
    function test_GetAllVaultIds() public {
        _createToken(VAULT_ID_2, vault2, "Staked QEURO Vault 2", "stQEURO2");
        _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        _createToken(VAULT_ID_3, vault3, "Staked QEURO Vault 3", "stQEURO3");

        uint256[] memory ids = factory.getAllVaultIds();
        assertEq(ids.length, 3);
        assertEq(ids[0], VAULT_ID_2);
        assertEq(ids[1], VAULT_ID_1);
        assertEq(ids[2], VAULT_ID_3);
    }

    /**
     * @notice Test getAllStakingTokens returns proxies in creation order
     */
    function test_GetAllStakingTokens() public {
        address proxy1 = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        address proxy2 = _createToken(VAULT_ID_2, vault2, "Staked QEURO Vault 2", "stQEURO2");

        address[] memory tokens = factory.getAllStakingTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], proxy1);
        assertEq(tokens[1], proxy2);
    }

    /**
     * @notice Test getAllStakingTokens returns empty array when no tokens created
     */
    function test_GetAllStakingTokens_Empty() public view {
        address[] memory tokens = factory.getAllStakingTokens();
        assertEq(tokens.length, 0);
    }

    // =============================================================================
    // updateImplementation
    // =============================================================================

    /**
     * @notice Test updateImplementation updates the address
     */
    function test_UpdateImplementation_Success() public {
        stQEUROToken newImpl = new stQEUROToken(timeProvider);
        address oldImpl = factory.stakingTokenImplementation();

        vm.expectEmit(true, true, false, false);
        emit ImplementationUpdated(oldImpl, address(newImpl));

        vm.prank(governance);
        factory.updateImplementation(address(newImpl));

        assertEq(factory.stakingTokenImplementation(), address(newImpl));
    }

    /**
     * @notice Test updateImplementation reverts when called by non-governance
     */
    function test_UpdateImplementation_NotGovernance_Reverts() public {
        stQEUROToken newImpl = new stQEUROToken(timeProvider);
        vm.expectRevert();
        vm.prank(attacker);
        factory.updateImplementation(address(newImpl));
    }

    /**
     * @notice Test updateImplementation reverts with zero address
     */
    function test_UpdateImplementation_ZeroAddress_Reverts() public {
        vm.expectRevert(StakingTokenFactoryErrorLibrary.InvalidImplementation.selector);
        vm.prank(governance);
        factory.updateImplementation(address(0));
    }

    /**
     * @notice Test updateImplementation reverts when same implementation
     */
    function test_UpdateImplementation_SameImpl_Reverts() public {
        vm.expectRevert(StakingTokenFactoryErrorLibrary.InvalidImplementation.selector);
        vm.prank(governance);
        factory.updateImplementation(factory.stakingTokenImplementation());
    }

    /**
     * @notice Test that updating implementation only affects new deployments
     */
    function test_UpdateImplementation_DoesNotAffectExistingProxies() public {
        address proxy1 = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        address impl1 = stQEUROToken(proxy1).associatedVault(); // just reading state

        // Update implementation
        stQEUROToken newImpl = new stQEUROToken(timeProvider);
        vm.prank(governance);
        factory.updateImplementation(address(newImpl));

        // Existing proxy unchanged
        assertEq(stQEUROToken(proxy1).associatedVault(), vault1, "existing proxy unaffected");

        // New proxy uses the new implementation (same logic, just verify creation succeeds)
        address proxy2 = _createToken(VAULT_ID_2, vault2, "Staked QEURO Vault 2", "stQEURO2");
        assertEq(stQEUROToken(proxy2).associatedVault(), vault2);

        // Suppress unused variable warning
        (impl1);
    }

    // =============================================================================
    // EMERGENCY / PAUSE
    // =============================================================================

    /**
     * @notice Test pause and unpause by emergency role
     */
    function test_PauseUnpause() public {
        assertFalse(factory.paused());

        vm.prank(admin);
        factory.pause();
        assertTrue(factory.paused());

        vm.prank(admin);
        factory.unpause();
        assertFalse(factory.paused());
    }

    /**
     * @notice Test pause reverts for non-emergency role
     */
    function test_Pause_NotEmergencyRole_Reverts() public {
        vm.expectRevert();
        vm.prank(attacker);
        factory.pause();
    }

    // =============================================================================
    // TOKEN INDEPENDENCE
    // =============================================================================

    /**
     * @notice Test that staking tokens are independent — state of one does not affect another
     */
    function test_StakingTokensAreIndependent() public {
        address proxy1 = _createToken(VAULT_ID_1, vault1, "Staked QEURO Vault 1", "stQEURO1");
        address proxy2 = _createToken(VAULT_ID_2, vault2, "Staked QEURO Vault 2", "stQEURO2");

        stQEUROToken token1 = stQEUROToken(proxy1);
        stQEUROToken token2 = stQEUROToken(proxy2);

        // Exchange rates are independent
        assertEq(token1.exchangeRate(), 1e18);
        assertEq(token2.exchangeRate(), 1e18);

        // Total underlying is independent
        assertEq(token1.totalUnderlying(), 0);
        assertEq(token2.totalUnderlying(), 0);

        // Different vault associations
        assertEq(token1.associatedVault(), vault1);
        assertEq(token2.associatedVault(), vault2);
        assertEq(token1.vaultId(), VAULT_ID_1);
        assertEq(token2.vaultId(), VAULT_ID_2);
    }

    // =============================================================================
    // FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test: create multiple tokens with distinct random vault IDs
     * @dev Uses a small array to avoid gas limits; vault IDs must be unique
     */
    function testFuzz_CreateMultipleTokens(uint8 vaultIdA, uint8 vaultIdB) public {
        vm.assume(vaultIdA != vaultIdB);
        address vaultA = address(uint160(0x1000 + uint256(vaultIdA)));
        address vaultB = address(uint160(0x2000 + uint256(vaultIdB)));
        vm.assume(vaultA != vaultB);

        address proxyA = _createToken(vaultIdA, vaultA, "Token A", "stA");
        address proxyB = _createToken(vaultIdB, vaultB, "Token B", "stB");

        assertEq(factory.tokenCount(), 2);
        assertEq(factory.stakingTokens(vaultIdA), proxyA);
        assertEq(factory.stakingTokens(vaultIdB), proxyB);
        assertFalse(proxyA == proxyB, "proxies must be distinct");
    }
}
