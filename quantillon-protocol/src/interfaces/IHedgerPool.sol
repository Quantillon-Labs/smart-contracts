// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHedgerPool {
    struct HedgerRiskConfig {
        uint256 minMarginRatio;
        uint256 maxLeverage;
        uint256 minPositionHoldBlocks;
        uint256 minMarginAmount;
        uint256 eurInterestRate;
        uint256 usdInterestRate;
        uint256 entryFee;
        uint256 exitFee;
        uint256 marginFee;
        uint256 rewardFeeSplit;
    }

    struct HedgerDependencyConfig {
        address treasury;
        address vault;
        address oracle;
        address yieldShift;
        address feeCollector;
    }

    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift,
        address _timelock,
        address _treasury,
        address _vault
    ) external;

    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);
    function exitHedgePosition(uint256 positionId) external returns (int256 pnl);
    function addMargin(uint256 positionId, uint256 amount) external;
    function removeMargin(uint256 positionId, uint256 amount) external;

    function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount) external;
    function recordUserRedeem(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) external;
    function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external;

    function claimHedgingRewards() external returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
    function withdrawPendingRewards(address recipient) external;

    function getTotalEffectiveHedgerCollateral(uint256 currentPrice) external view returns (uint256 totalEffectiveCollateral);
    function hasActiveHedger() external view returns (bool);

    function configureRiskAndFees(HedgerRiskConfig calldata cfg) external;
    function configureDependencies(HedgerDependencyConfig calldata cfg) external;

    function emergencyClosePosition(address hedger, uint256 positionId) external;
    function pause() external;
    function unpause() external;
    function recover(address token, uint256 amount) external;

    function setSingleHedger(address hedger) external;
    function applySingleHedgerRotation() external;
    function fundRewardReserve(uint256 amount) external;

    function usdc() external view returns (IERC20);
    function oracle() external view returns (address);
    function yieldShift() external view returns (address);
    function vault() external view returns (address);
    function treasury() external view returns (address);

    function coreParams()
        external
        view
        returns (
            uint64 minMarginRatio,
            uint16 maxLeverage,
            uint16 entryFee,
            uint16 exitFee,
            uint16 marginFee,
            uint16 eurInterestRate,
            uint16 usdInterestRate,
            uint8 reserved
        );

    function totalMargin() external view returns (uint256);
    function totalExposure() external view returns (uint256);
    function totalFilledExposure() external view returns (uint256);

    function singleHedger() external view returns (address);
    function minPositionHoldBlocks() external view returns (uint256);
    function minMarginAmount() external view returns (uint256);
    function pendingRewardWithdrawals(address hedger) external view returns (uint256);

    function feeCollector() external view returns (address);
    function rewardFeeSplit() external view returns (uint256);
    function MAX_REWARD_FEE_SPLIT() external view returns (uint256);

    function pendingSingleHedger() external view returns (address);
    function singleHedgerPendingAt() external view returns (uint256);

    function hedgerLastRewardBlock(address hedger) external view returns (uint256);

    function positions(uint256 positionId)
        external
        view
        returns (
            address hedger,
            uint96 positionSize,
            uint96 filledVolume,
            uint96 margin,
            uint96 entryPrice,
            uint32 entryTime,
            uint32 lastUpdateTime,
            int128 unrealizedPnL,
            int128 realizedPnL,
            uint16 leverage,
            bool isActive,
            uint128 qeuroBacked,
            uint64 openBlock
        );

    event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
    event RewardReserveFunded(address indexed funder, uint256 amount);
    event SingleHedgerRotationProposed(address indexed currentHedger, address indexed pendingHedger, uint256 activatesAt);
    event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
}
