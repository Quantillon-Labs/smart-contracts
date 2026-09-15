// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {QuantillonRebalancerModule} from "../src/automation/QuantillonRebalancerModule.sol";

contract RebalanceToken is ERC20 {
    constructor() ERC20("Test USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RebalanceOracle {
    uint256 public price = 1e18;
    bool public valid = true;

    function set(uint256 price_, bool valid_) external {
        price = price_;
        valid = valid_;
    }

    function getEurUsdPrice() external view returns (uint256, bool) {
        return (price, valid);
    }
}

contract RebalanceVault {
    RebalanceToken public usdc;
    RebalanceToken public qeuro;
    uint256 public minCollateralizationRatioForMinting = 102.5e18;

    constructor(RebalanceToken token) {
        usdc = token;
        qeuro = new RebalanceToken();
    }
    function addHedgerDeposit(uint256) external {}

    function withdrawHedgerDeposit(address to, uint256 amount) external {
        usdc.transfer(to, amount);
    }

    function getTotalUsdcAvailable() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function totalMinted() external view returns (uint256) {
        return qeuro.totalSupply();
    }

    function setMinimum(uint256 minimum) external {
        minCollateralizationRatioForMinting = minimum;
    }
}

// Offline execution harness only; the fork test below uses the user's actual Safe 1.4.1.
contract RebalanceSafeHarness {
    mapping(address => bool) public modules;

    function enableModule(address module) external {
        require(msg.sender == address(this));
        modules[module] = true;
    }

    function disableModule(address, address module) external {
        require(msg.sender == address(this));
        modules[module] = false;
    }

    function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        returns (bool, bytes memory)
    {
        require(modules[msg.sender] && operation == 0 && value == 0);
        return to.call(data);
    }
}

contract QuantillonRebalancerModuleTest is Test {
    QuantillonRebalancerModule internal module;
    HedgerPool internal pool;
    RebalanceToken internal usdc;
    RebalanceOracle internal oracle;
    RebalanceVault internal vault;
    address internal safe;
    address internal operator = address(0xB07);

    function setUp() public {
        vm.warp(10 days + 1 hours);
        _setup(address(new RebalanceSafeHarness()));
    }

    function _setup(address safe_) internal {
        safe = safe_;
        usdc = new RebalanceToken();
        oracle = new RebalanceOracle();
        vault = new RebalanceVault(usdc);
        TimeProvider clock = TimeProvider(
            address(
                new ERC1967Proxy(
                    address(new TimeProvider()),
                    abi.encodeCall(TimeProvider.initialize, (address(this), address(this), address(this)))
                )
            )
        );
        pool = HedgerPool(
            address(
                new ERC1967Proxy(
                    address(new HedgerPool(clock)),
                    abi.encodeCall(
                        HedgerPool.initialize,
                        (
                            address(this),
                            address(usdc),
                            address(oracle),
                            address(0x123),
                            address(this),
                            address(this),
                            address(vault)
                        )
                    )
                )
            )
        );
        pool.setSingleHedger(safe);
        usdc.mint(safe, 5_000e6);
        vm.startPrank(safe);
        usdc.approve(address(pool), 1_000e6);
        pool.enterHedgePosition(1_000e6, 10);
        vm.stopPrank();
        usdc.mint(address(vault), 9_000e6);
        vault.qeuro().mint(address(0xAAA), 9_000e18);
        vm.prank(address(vault));
        pool.recordUserMint(9_000e6, 1e18, 9_000e18);
        module = new QuantillonRebalancerModule(safe, address(pool), 1, operator, _limits());
        vm.prank(safe);
        (bool enabled,) = safe.call(abi.encodeWithSignature("enableModule(address)", address(module)));
        assertTrue(enabled);
        vm.prank(safe);
        module.setPaused(false);
    }

    function _limits() internal pure returns (QuantillonRebalancerModule.Limits memory) {
        return QuantillonRebalancerModule.Limits(500e6, 1_000e6, 60, 100e6, 600, 100, 100);
    }

    function _add(uint256 amount) internal {
        uint256 sequence = module.nonce();
        vm.prank(operator);
        module.addMargin(amount, sequence, vm.getBlockTimestamp() + 300);
    }

    function _remove(uint256 amount) internal {
        uint256 sequence = module.nonce();
        vm.prank(operator);
        module.removeMargin(amount, sequence, vm.getBlockTimestamp() + 300);
    }

    function _expectAdd(uint256 amount, bytes4 error) internal {
        uint256 sequence = module.nonce();
        vm.prank(operator);
        if (error == bytes4(0)) vm.expectRevert();
        else vm.expectRevert(error);
        module.addMargin(amount, sequence, vm.getBlockTimestamp() + 300);
    }

    function _expectRemove(uint256 amount, bytes4 error) internal {
        uint256 sequence = module.nonce();
        vm.prank(operator);
        vm.expectRevert(error);
        module.removeMargin(amount, sequence, vm.getBlockTimestamp() + 300);
    }

    function testAddAndRemoveUseSafeFundsAndLeaveNoAllowance() public {
        uint256 beforeBalance = usdc.balanceOf(safe);
        _add(100e6);
        assertEq(usdc.balanceOf(safe), beforeBalance - 100e6);
        assertEq(usdc.allowance(safe, address(pool)), 0);
        assertEq(usdc.balanceOf(operator), 0);
        vm.warp(vm.getBlockTimestamp() + 60);
        _remove(50e6);
        assertEq(usdc.balanceOf(safe), beforeBalance - 50e6);
        assertEq(module.windowUsage(), 150e6);
        assertEq(module.nonce(), 2);
    }

    function testOperatorCannotConfigureOrExecuteArbitraryCalls() public {
        vm.startPrank(operator);
        vm.expectRevert(QuantillonRebalancerModule.Unauthorized.selector);
        module.configure(operator, _limits());
        vm.expectRevert(QuantillonRebalancerModule.Unauthorized.selector);
        module.setPaused(false);
        (bool ok,) = address(module)
            .call(
                abi.encodeWithSignature(
                    "execute(address,bytes)", address(usdc), abi.encodeCall(usdc.transfer, (operator, 1e6))
                )
            );
        assertFalse(ok);
        vm.stopPrank();
    }

    function testUnauthorizedCallerAndPause() public {
        vm.expectRevert(QuantillonRebalancerModule.Unauthorized.selector);
        module.addMargin(1e6, 0, vm.getBlockTimestamp() + 300);
        vm.prank(safe);
        module.setPaused(true);
        _expectAdd(1e6, QuantillonRebalancerModule.ModulePaused.selector);
    }

    function testNonceDeadlineAndCooldown() public {
        _add(1e6);
        vm.startPrank(operator);
        vm.expectRevert(QuantillonRebalancerModule.InvalidRequest.selector);
        module.addMargin(1e6, 0, vm.getBlockTimestamp() + 300);
        vm.expectRevert(QuantillonRebalancerModule.InvalidRequest.selector);
        module.addMargin(1e6, 1, vm.getBlockTimestamp() - 1);
        vm.expectRevert(QuantillonRebalancerModule.InvalidRequest.selector);
        module.addMargin(1e6, 1, vm.getBlockTimestamp() + 901);
        vm.expectRevert(QuantillonRebalancerModule.CooldownActive.selector);
        module.addMargin(1e6, 1, vm.getBlockTimestamp() + 300);
        vm.stopPrank();
    }

    function testPerActionLimit() public {
        _expectAdd(501e6, QuantillonRebalancerModule.LimitExceeded.selector);
    }

    function testUsageCannotResetAtMidnightOrThroughReconfiguration() public {
        vm.warp(11 days - 120);
        _add(500e6);
        vm.warp(11 days - 60);
        _add(500e6);
        vm.warp(11 days);
        vm.prank(safe);
        module.configure(operator, _limits());
        _expectRemove(1e6, QuantillonRebalancerModule.LimitExceeded.selector);
        vm.warp(12 days);
        assertEq(module.windowUsage(), 0);
        _remove(1e6);
    }

    function testPositionFloorFailureRollsBackTransferAndNonce() public {
        uint256 beforeBalance = usdc.balanceOf(safe);
        _expectRemove(500e6, QuantillonRebalancerModule.PositionFloorBreached.selector);
        assertEq(usdc.balanceOf(safe), beforeBalance);
        assertEq(module.nonce(), 0);
        assertEq(module.windowUsage(), 0);
    }

    function testVaultFloorFailureRollsBackTransfer() public {
        vault.setMinimum(111e18);
        uint256 beforeBalance = usdc.balanceOf(safe);
        _expectRemove(50e6, QuantillonRebalancerModule.VaultFloorBreached.selector);
        assertEq(usdc.balanceOf(safe), beforeBalance);
        assertEq(module.nonce(), 0);
    }

    function testFreshPriceDrivesVaultFloor() public {
        oracle.set(1.01e18, true);
        vault.setMinimum(109e18);
        // Cached-price CR would pass: 9,950 / 9,000 > 110%; fresh-price CR fails.
        _expectRemove(50e6, QuantillonRebalancerModule.VaultFloorBreached.selector);
    }

    function testReserveCannotBeConsumedByBot() public {
        QuantillonRebalancerModule.Limits memory policy = _limits();
        policy.minSafeReserveUsdc = usdc.balanceOf(safe);
        vm.prank(safe);
        module.configure(operator, policy);
        _expectAdd(1e6, QuantillonRebalancerModule.SafeReserveBreached.selector);
    }

    function testInvalidOracleBlocksWithdrawalButAllowsRecoveryDeposit() public {
        oracle.set(1e18, false);
        _expectRemove(1e6, QuantillonRebalancerModule.SafeExecutionFailed.selector);
        _add(1e6);
    }

    function testRevokingModuleBlocksBot() public {
        vm.prank(safe);
        (bool disabled,) =
            safe.call(abi.encodeWithSignature("disableModule(address,address)", address(1), address(module)));
        assertTrue(disabled);
        _expectAdd(1e6, bytes4(0));
        assertEq(module.nonce(), 0);
    }

    function testChangedPoolDependenciesBlockExecution() public {
        vm.mockCall(address(pool), abi.encodeWithSignature("vault()"), abi.encode(address(0xBAD)));
        _expectAdd(1e6, QuantillonRebalancerModule.DependenciesChanged.selector);
    }

    function testWrongPositionOwnerBlocksExecution() public {
        address otherSafe = address(new RebalanceSafeHarness());
        module = new QuantillonRebalancerModule(otherSafe, address(pool), 1, operator, _limits());
        vm.prank(otherSafe);
        module.setPaused(false);
        _expectAdd(1e6, QuantillonRebalancerModule.WrongPositionOwner.selector);
    }

    function testFalseTokenApprovalRollsBackUsage() public {
        vm.mockCall(address(usdc), abi.encodeWithSelector(usdc.approve.selector), abi.encode(false));
        _expectAdd(1e6, QuantillonRebalancerModule.TokenOperationFailed.selector);
        assertEq(module.nonce(), 0);
        assertEq(module.windowUsage(), 0);
    }

    function testFuzzWithinLimitsPreservesFunds(uint96 raw) public {
        uint256 amount = bound(uint256(raw), 1, 500e6);
        uint256 beforeBalance = usdc.balanceOf(safe);
        _add(amount);
        vm.warp(vm.getBlockTimestamp() + 60);
        _remove(amount);
        assertEq(usdc.balanceOf(safe), beforeBalance);
        assertEq(usdc.balanceOf(operator), 0);
        assertEq(usdc.allowance(safe, address(pool)), 0);
    }

    function testForkActualSafe141() public {
        string memory rpc = vm.envOr("REBALANCER_TEST_BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc);
        _setup(0x1d7fF432a93d0085Fb69474c7E567f859829e6cd);
        testAddAndRemoveUseSafeFundsAndLeaveNoAllowance();
    }
}
