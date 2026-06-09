// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Test-only QTIToken exposing a mint helper.
contract QTITokenPoCHelper is QTIToken {
    constructor(TimeProvider _tp) QTIToken(_tp) {}
    function testMint(address to, uint256 amount) external { _mint(to, amount); }
}

/// @notice PoC for audit finding QTI-M1: adding to an existing lock collapses voting power.
contract AuditPoC_QTILock is Test {
    QTITokenPoCHelper internal qti;
    address internal admin = address(0x1);
    address internal treasury = address(0x2);
    address internal governance = address(0x6);
    address internal user1 = address(0x3);

    function setUp() public {
        TimeProvider tpImpl = new TimeProvider();
        ERC1967Proxy tpProxy = new ERC1967Proxy(
            address(tpImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, governance, admin)
        );
        TimeProvider tp = TimeProvider(address(tpProxy));

        QTITokenPoCHelper impl = new QTITokenPoCHelper(tp);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(QTIToken.initialize.selector, admin, treasury, address(0x123))
        );
        qti = QTITokenPoCHelper(address(proxy));
        qti.testMint(user1, 1_000_000e18);
    }

    /// @dev Lock 100k for 365d, then top up with just 1 QTI for 365d.
    ///      Despite the locked amount increasing, voting power must NOT decrease.
    function test_PoC_AddingToLockCollapsesVotingPower() public {
        vm.prank(user1);
        qti.lock(100_000e18, 365 days);

        (uint256 amount0, , uint256 vp0, , , ) = qti.getLockInfo(user1);
        uint256 total0 = qti.totalVotingPower();
        emit log_named_uint("amount after first lock ", amount0);
        emit log_named_uint("votingPower after first ", vp0);
        emit log_named_uint("totalVotingPower after 1", total0);

        // Top up with 1 QTI, same max duration.
        vm.prank(user1);
        qti.lock(1e18, 365 days);

        (uint256 amount1, , uint256 vp1, , , ) = qti.getLockInfo(user1);
        uint256 total1 = qti.totalVotingPower();
        emit log_named_uint("amount after top-up      ", amount1);
        emit log_named_uint("votingPower after top-up ", vp1);
        emit log_named_uint("totalVotingPower after 2 ", total1);

        // Sanity: locked amount strictly increased.
        assertGt(amount1, amount0, "locked amount should increase");

        // The bug: voting power collapses to reflect only the 1 QTI top-up.
        // A correct implementation would have vp1 >= vp0. This assertion documents
        // the buggy behavior; it PASSES while the bug exists.
        assertLt(vp1, vp0, "BUG: voting power dropped after adding tokens");
        assertLt(total1, total0, "BUG: totalVotingPower dropped after adding tokens");
    }
}
