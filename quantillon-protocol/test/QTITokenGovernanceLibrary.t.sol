// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {QTITokenGovernanceLibrary} from "../src/libraries/QTITokenGovernanceLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title QTITokenGovernanceLibraryTest
 * @notice Comprehensive test suite for QTITokenGovernanceLibrary
 *
 * @dev This test suite covers:
 *      - Voting power multiplier calculations
 *      - Voting power calculations with overflow protection
 *      - Linear decay voting power calculations
 *      - Unlock time calculations
 *      - Batch lock processing
 *      - Decentralization level calculations
 *      - Edge cases and boundary conditions
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract QTITokenGovernanceLibraryTest is Test {
    // =============================================================================
    // CONSTANTS (matching library)
    // =============================================================================

    uint256 constant MAX_LOCK_TIME = 365 days;
    uint256 constant MIN_LOCK_TIME = 7 days;
    uint256 constant MAX_VE_QTI_MULTIPLIER = 4;
    uint256 constant PRECISION = 1e18;

    // =============================================================================
    // VOTING POWER MULTIPLIER TESTS
    // =============================================================================

    /**
     * @notice Test minimum lock time gives 1x multiplier
     */
    function test_CalculateVotingPowerMultiplier_MinLockTime_Returns1x() public pure {
        uint256 multiplier = QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(MIN_LOCK_TIME);

        assertEq(multiplier, 1e18, "Minimum lock time should give 1x multiplier");
    }

    /**
     * @notice Test maximum lock time gives 4x multiplier
     */
    function test_CalculateVotingPowerMultiplier_MaxLockTime_Returns4x() public pure {
        uint256 multiplier = QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(MAX_LOCK_TIME);

        assertEq(multiplier, 4e18, "Maximum lock time should give 4x multiplier");
    }

    /**
     * @notice Test multiplier is linear between min and max
     */
    function test_CalculateVotingPowerMultiplier_HalfwayPoint_Returns2_5x() public pure {
        // Halfway between 7 days and 365 days
        uint256 halfwayLockTime = MIN_LOCK_TIME + (MAX_LOCK_TIME - MIN_LOCK_TIME) / 2;

        uint256 multiplier = QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(halfwayLockTime);

        // Should be approximately 2.5x (1 + 1.5 = 2.5)
        uint256 expected = 25e17; // 2.5e18
        assertApproxEqAbs(multiplier, expected, 1e15, "Halfway should give ~2.5x multiplier");
    }

    /**
     * @notice Test multiplier caps at 4x for times beyond max
     */
    function test_CalculateVotingPowerMultiplier_BeyondMax_CapsAt4x() public pure {
        uint256 multiplier = QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(MAX_LOCK_TIME * 2);

        assertEq(multiplier, 4e18, "Beyond max should cap at 4x");
    }

    /**
     * @notice Fuzz test multiplier is always between 1x and 4x
     */
    function testFuzz_CalculateVotingPowerMultiplier_AlwaysInRange(uint256 lockTime) public pure {
        vm.assume(lockTime >= MIN_LOCK_TIME);
        vm.assume(lockTime <= MAX_LOCK_TIME); // Avoid overflow with huge lockTime

        uint256 multiplier = QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(lockTime);

        assertGe(multiplier, 1e18, "Multiplier should be at least 1x");
        assertLe(multiplier, 4e18, "Multiplier should be at most 4x");
    }

    // =============================================================================
    // VOTING POWER CALCULATION TESTS
    // =============================================================================

    /**
     * @notice Test voting power with minimum lock time
     */
    function test_CalculateVotingPower_MinLockTime_Returns1xAmount() public pure {
        uint256 amount = 1000e18;
        uint256 votingPower = QTITokenGovernanceLibrary.calculateVotingPower(amount, MIN_LOCK_TIME);

        assertEq(votingPower, amount, "Min lock should give 1x voting power");
    }

    /**
     * @notice Test voting power with maximum lock time
     */
    function test_CalculateVotingPower_MaxLockTime_Returns4xAmount() public pure {
        uint256 amount = 1000e18;
        uint256 votingPower = QTITokenGovernanceLibrary.calculateVotingPower(amount, MAX_LOCK_TIME);

        assertEq(votingPower, amount * 4, "Max lock should give 4x voting power");
    }

    /**
     * @notice Test voting power overflow protection
     */
    function test_CalculateVotingPower_OverflowProtection_Reverts() public {
        // Amount that would overflow uint96 when multiplied by 4
        uint256 amount = uint256(type(uint96).max) / 2;

        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        QTITokenGovernanceLibrary.calculateVotingPower(amount, MAX_LOCK_TIME);
    }

    /**
     * @notice Test voting power with zero amount
     */
    function test_CalculateVotingPower_ZeroAmount_ReturnsZero() public pure {
        uint256 votingPower = QTITokenGovernanceLibrary.calculateVotingPower(0, MAX_LOCK_TIME);

        assertEq(votingPower, 0, "Zero amount should give zero voting power");
    }

    // =============================================================================
    // CURRENT VOTING POWER (LINEAR DECAY) TESTS
    // =============================================================================

    /**
     * @notice Test current voting power when lock expired returns zero
     */
    function test_CalculateCurrentVotingPower_Expired_ReturnsZero() public view {
        QTITokenGovernanceLibrary.LockInfo memory lockInfo = QTITokenGovernanceLibrary.LockInfo({
            amount: 1000e18,
            unlockTime: uint32(block.timestamp - 1), // Expired
            votingPower: 1000e18,
            lastClaimTime: 0,
            initialVotingPower: 1000e18,
            lockTime: uint32(30 days)
        });

        uint256 currentPower = QTITokenGovernanceLibrary.calculateCurrentVotingPower(
            lockInfo,
            block.timestamp
        );

        assertEq(currentPower, 0, "Expired lock should have zero power");
    }

    /**
     * @notice Test current voting power with zero amount returns zero
     */
    function test_CalculateCurrentVotingPower_ZeroAmount_ReturnsZero() public view {
        QTITokenGovernanceLibrary.LockInfo memory lockInfo = QTITokenGovernanceLibrary.LockInfo({
            amount: 0,
            unlockTime: uint32(block.timestamp + 30 days),
            votingPower: 0,
            lastClaimTime: 0,
            initialVotingPower: 0,
            lockTime: uint32(30 days)
        });

        uint256 currentPower = QTITokenGovernanceLibrary.calculateCurrentVotingPower(
            lockInfo,
            block.timestamp
        );

        assertEq(currentPower, 0, "Zero amount should have zero power");
    }

    /**
     * @notice Test current voting power at full remaining time returns initial power
     */
    function test_CalculateCurrentVotingPower_FullTime_ReturnsInitialPower() public view {
        uint256 initialPower = 1000e18;
        uint32 lockDuration = uint32(30 days);
        uint256 startTime = block.timestamp;

        QTITokenGovernanceLibrary.LockInfo memory lockInfo = QTITokenGovernanceLibrary.LockInfo({
            amount: 1000e18,
            unlockTime: uint32(startTime + lockDuration),
            votingPower: uint96(initialPower),
            lastClaimTime: 0,
            initialVotingPower: uint96(initialPower),
            lockTime: lockDuration
        });

        uint256 currentPower = QTITokenGovernanceLibrary.calculateCurrentVotingPower(
            lockInfo,
            startTime
        );

        assertEq(currentPower, initialPower, "Full time remaining should return initial power");
    }

    /**
     * @notice Test current voting power decays linearly
     */
    function test_CalculateCurrentVotingPower_HalfwayDecay_ReturnsHalfPower() public view {
        uint256 initialPower = 1000e18;
        uint32 lockDuration = uint32(30 days);
        uint256 startTime = block.timestamp;

        QTITokenGovernanceLibrary.LockInfo memory lockInfo = QTITokenGovernanceLibrary.LockInfo({
            amount: 1000e18,
            unlockTime: uint32(startTime + lockDuration),
            votingPower: uint96(initialPower),
            lastClaimTime: 0,
            initialVotingPower: uint96(initialPower),
            lockTime: lockDuration
        });

        // Check at halfway point
        uint256 currentPower = QTITokenGovernanceLibrary.calculateCurrentVotingPower(
            lockInfo,
            startTime + lockDuration / 2
        );

        assertEq(currentPower, initialPower / 2, "Halfway should return half power");
    }

    // =============================================================================
    // UNLOCK TIME CALCULATION TESTS
    // =============================================================================

    /**
     * @notice Test unlock time calculation for new lock
     */
    function test_CalculateUnlockTime_NewLock_ReturnsCorrectTime() public view {
        uint256 currentTime = block.timestamp;
        uint256 lockTime = 30 days;

        uint256 unlockTime = QTITokenGovernanceLibrary.calculateUnlockTime(
            currentTime,
            lockTime,
            0 // No existing lock
        );

        assertEq(unlockTime, currentTime + lockTime, "New lock should set correct unlock time");
    }

    /**
     * @notice Test unlock time extends existing lock
     */
    function test_CalculateUnlockTime_ExistingLock_ExtendsTime() public view {
        uint256 currentTime = block.timestamp;
        uint256 lockTime = 30 days;
        uint256 existingUnlock = currentTime + 15 days; // Still active

        uint256 unlockTime = QTITokenGovernanceLibrary.calculateUnlockTime(
            currentTime,
            lockTime,
            existingUnlock
        );

        assertEq(unlockTime, existingUnlock + lockTime, "Should extend existing lock");
    }

    /**
     * @notice Test unlock time with expired existing lock
     */
    function test_CalculateUnlockTime_ExpiredLock_StartsNew() public view {
        uint256 currentTime = block.timestamp;
        uint256 lockTime = 30 days;
        uint256 existingUnlock = currentTime - 1; // Expired

        uint256 unlockTime = QTITokenGovernanceLibrary.calculateUnlockTime(
            currentTime,
            lockTime,
            existingUnlock
        );

        assertEq(unlockTime, currentTime + lockTime, "Expired lock should start new");
    }

    /**
     * @notice Test unlock time overflow protection
     */
    function test_CalculateUnlockTime_Overflow_Reverts() public {
        uint256 currentTime = type(uint32).max - 1 days;
        uint256 lockTime = 30 days; // Would overflow uint32

        vm.expectRevert(CommonErrorLibrary.InvalidTime.selector);
        QTITokenGovernanceLibrary.calculateUnlockTime(currentTime, lockTime, 0);
    }

    // =============================================================================
    // VALIDATE AND CALCULATE TOTAL AMOUNT TESTS
    // =============================================================================

    /**
     * @notice Test validation with valid amounts and lock times
     */
    function test_ValidateAndCalculateTotalAmount_ValidInputs_ReturnsTotalAmount() public pure {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e18;
        amounts[1] = 200e18;
        amounts[2] = 300e18;

        uint256[] memory lockTimes = new uint256[](3);
        lockTimes[0] = 30 days;
        lockTimes[1] = 60 days;
        lockTimes[2] = 90 days;

        uint256 total = QTITokenGovernanceLibrary.validateAndCalculateTotalAmount(amounts, lockTimes);

        assertEq(total, 600e18, "Total should be sum of amounts");
    }

    /**
     * @notice Test validation with zero amount reverts
     */
    function test_ValidateAndCalculateTotalAmount_ZeroAmount_Reverts() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 0; // Invalid

        uint256[] memory lockTimes = new uint256[](2);
        lockTimes[0] = 30 days;
        lockTimes[1] = 30 days;

        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        QTITokenGovernanceLibrary.validateAndCalculateTotalAmount(amounts, lockTimes);
    }

    /**
     * @notice Test validation with lock time too short reverts
     */
    function test_ValidateAndCalculateTotalAmount_LockTimeTooShort_Reverts() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;

        uint256[] memory lockTimes = new uint256[](1);
        lockTimes[0] = 1 days; // Too short

        vm.expectRevert(CommonErrorLibrary.LockTimeTooShort.selector);
        QTITokenGovernanceLibrary.validateAndCalculateTotalAmount(amounts, lockTimes);
    }

    /**
     * @notice Test validation with lock time too long reverts
     */
    function test_ValidateAndCalculateTotalAmount_LockTimeTooLong_Reverts() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;

        uint256[] memory lockTimes = new uint256[](1);
        lockTimes[0] = 400 days; // Too long

        vm.expectRevert(CommonErrorLibrary.LockTimeTooLong.selector);
        QTITokenGovernanceLibrary.validateAndCalculateTotalAmount(amounts, lockTimes);
    }

    // =============================================================================
    // DECENTRALIZATION LEVEL TESTS
    // =============================================================================

    /**
     * @notice Test decentralization level at start is zero
     */
    function test_CalculateDecentralizationLevel_AtStart_ReturnsZero() public view {
        uint256 startTime = block.timestamp;

        uint256 level = QTITokenGovernanceLibrary.calculateDecentralizationLevel(
            startTime,     // currentTime = startTime
            startTime,     // decentralizationStartTime
            365 days,      // decentralizationDuration
            365 days       // maxTimeElapsed
        );

        assertEq(level, 0, "Level at start should be zero");
    }

    /**
     * @notice Test decentralization level at end is 10000 (100%)
     */
    function test_CalculateDecentralizationLevel_AtEnd_Returns10000() public view {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;

        uint256 level = QTITokenGovernanceLibrary.calculateDecentralizationLevel(
            startTime + duration,  // currentTime at end
            startTime,
            duration,
            duration
        );

        assertEq(level, 10000, "Level at end should be 10000");
    }

    /**
     * @notice Test decentralization level caps at 10000
     */
    function test_CalculateDecentralizationLevel_BeyondEnd_CapsAt10000() public view {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;

        uint256 level = QTITokenGovernanceLibrary.calculateDecentralizationLevel(
            startTime + duration * 2,  // Way past end
            startTime,
            duration,
            duration * 2
        );

        assertEq(level, 10000, "Level should cap at 10000");
    }

    /**
     * @notice Test decentralization level respects maxTimeElapsed
     */
    function test_CalculateDecentralizationLevel_RespectsMaxTimeElapsed() public view {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 maxTime = 100 days;

        uint256 level = QTITokenGovernanceLibrary.calculateDecentralizationLevel(
            startTime + 200 days,  // Well past maxTime
            startTime,
            duration,
            maxTime
        );

        // maxTime = 100 days out of 365 days = 2739 basis points
        uint256 expected = maxTime * 10000 / duration;
        assertEq(level, expected, "Level should respect maxTimeElapsed");
    }

    // =============================================================================
    // UPDATE LOCK INFO TESTS
    // =============================================================================

    /**
     * @notice Test update lock info creates valid struct
     */
    function test_UpdateLockInfo_ValidInputs_ReturnsCorrectStruct() public view {
        uint256 amount = 1000e18;
        uint256 unlockTime = block.timestamp + 30 days;
        uint256 votingPower = 2000e18;
        uint256 lockTime = 30 days;

        QTITokenGovernanceLibrary.LockInfo memory info = QTITokenGovernanceLibrary.updateLockInfo(
            amount,
            unlockTime,
            votingPower,
            lockTime
        );

        assertEq(info.amount, amount, "Amount should match");
        assertEq(info.unlockTime, unlockTime, "Unlock time should match");
        assertEq(info.initialVotingPower, votingPower, "Initial voting power should match");
        assertEq(info.lockTime, lockTime, "Lock time should match");
        assertEq(info.votingPower, votingPower, "Voting power should match");
    }

    /**
     * @notice Test update lock info with amount exceeding uint96 reverts
     */
    function test_UpdateLockInfo_AmountOverflow_Reverts() public {
        uint256 amount = uint256(type(uint96).max) + 1;

        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        QTITokenGovernanceLibrary.updateLockInfo(
            amount,
            block.timestamp + 30 days,
            1000e18,
            30 days
        );
    }

    /**
     * @notice Test update lock info with voting power exceeding uint96 reverts
     */
    function test_UpdateLockInfo_VotingPowerOverflow_Reverts() public {
        uint256 votingPower = uint256(type(uint96).max) + 1;

        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        QTITokenGovernanceLibrary.updateLockInfo(
            1000e18,
            block.timestamp + 30 days,
            votingPower,
            30 days
        );
    }

    // =============================================================================
    // FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test voting power multiplier monotonicity
     */
    function testFuzz_VotingPowerMultiplier_Monotonic(uint64 lockTime1, uint64 lockTime2) public pure {
        lockTime1 = uint64(bound(lockTime1, MIN_LOCK_TIME, MAX_LOCK_TIME));
        lockTime2 = uint64(bound(lockTime2, MIN_LOCK_TIME, MAX_LOCK_TIME));
        if (lockTime1 > lockTime2) (lockTime1, lockTime2) = (lockTime2, lockTime1);

        uint256 mult1 = QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(uint256(lockTime1));
        uint256 mult2 = QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(uint256(lockTime2));

        assertLe(mult1, mult2, "Multiplier should be monotonically increasing");
    }

    /**
     * @notice Fuzz test voting power proportional to amount
     */
    function testFuzz_VotingPower_ProportionalToAmount(uint64 amount, uint64 lockTime) public pure {
        vm.assume(lockTime >= MIN_LOCK_TIME);
        vm.assume(lockTime <= MAX_LOCK_TIME);
        vm.assume(amount > 0);
        vm.assume(amount < type(uint96).max / 4); // Avoid overflow

        uint256 power1 = QTITokenGovernanceLibrary.calculateVotingPower(uint256(amount), uint256(lockTime));
        uint256 power2 = QTITokenGovernanceLibrary.calculateVotingPower(uint256(amount) * 2, uint256(lockTime));

        assertApproxEqAbs(power2, power1 * 2, 1, "Voting power should be proportional to amount (rounding)");
    }

    /**
     * @notice Fuzz test decentralization level bounds
     */
    function testFuzz_DecentralizationLevel_Bounds(uint64 elapsed, uint64 duration) public view {
        vm.assume(duration > 0);

        uint256 startTime = block.timestamp;

        uint256 level = QTITokenGovernanceLibrary.calculateDecentralizationLevel(
            startTime + uint256(elapsed),
            startTime,
            uint256(duration),
            type(uint256).max
        );

        assertLe(level, 10000, "Level should not exceed 10000");
    }
}
