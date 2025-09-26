// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ErrorLibrary} from "./ErrorLibrary.sol";
import {AccessControlLibrary} from "./AccessControlLibrary.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title HedgerPoolOptimizationLibrary
 * @notice Library for HedgerPool data packing, validation, and utility functions
 * @dev Extracts utility functions from HedgerPool to reduce contract size
 * @author Quantillon Labs
 */
library HedgerPoolOptimizationLibrary {
    
    // =============================================================================
    // DATA PACKING FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Packs position open data into a single bytes32 for gas efficiency
     * @dev Encodes position size, margin, leverage, and entry price into a compact format
     * @param positionSize Size of the position in USDC
     * @param margin Margin amount for the position
     * @param leverage Leverage multiplier for the position
     * @param entryPrice Price at which the position was opened
     * @return Packed data as bytes32
     * @custom:security No security implications - pure data packing function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function packPositionOpenData(
        uint256 positionSize,
        uint256 margin, 
        uint256 leverage,
        uint256 entryPrice
    ) external pure returns (bytes32) {
        return bytes32(
            (uint256(uint64(positionSize)) << 192) |
            (uint256(uint64(margin)) << 128) |
            (uint256(uint32(leverage)) << 96) |
            uint256(uint96(entryPrice))
        );
    }
    
    /**
     * @notice Packs position close data into a single bytes32 for gas efficiency
     * @dev Encodes exit price, PnL, and timestamp into a compact format
     * @param exitPrice Price at which the position was closed
     * @param pnl Profit or loss from the position (can be negative)
     * @param timestamp Timestamp when the position was closed
     * @return Packed data as bytes32
     * @custom:security No security implications - pure data packing function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function packPositionCloseData(
        uint256 exitPrice,
        int256 pnl,
        uint256 timestamp
    ) external pure returns (bytes32) {
        uint256 absPnl = uint256(pnl < 0 ? -pnl : pnl);
        uint256 signFlag = pnl < 0 ? (1 << 63) : 0;
        return bytes32(
            (uint256(uint96(exitPrice)) << 160) |
            (uint256(uint96(absPnl)) << 64) |
            uint256(uint64(timestamp)) |
            signFlag
        );
    }
    
    /**
     * @notice Packs margin data into a single bytes32 for gas efficiency
     * @dev Encodes margin amount, new margin ratio, and operation type
     * @param marginAmount Amount of margin added or removed
     * @param newMarginRatio New margin ratio after the operation
     * @param isAdded True if margin was added, false if removed
     * @return Packed data as bytes32
     * @custom:security No security implications - pure data packing function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function packMarginData(
        uint256 marginAmount,
        uint256 newMarginRatio,
        bool isAdded
    ) external pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(marginAmount)) << 128) |
            (uint256(uint128(newMarginRatio)) << 1) |
            (isAdded ? 1 : 0)
        );
    }
    
    /**
     * @notice Packs liquidation data into a single bytes32 for gas efficiency
     * @dev Encodes liquidation reward and remaining margin
     * @param liquidationReward Reward paid to the liquidator
     * @param remainingMargin Margin remaining after liquidation
     * @return Packed data as bytes32
     * @custom:security No security implications - pure data packing function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function packLiquidationData(
        uint256 liquidationReward,
        uint256 remainingMargin
    ) external pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(liquidationReward)) << 128) |
            uint256(uint128(remainingMargin))
        );
    }
    
    /**
     * @notice Packs reward data into a single bytes32 for gas efficiency
     * @dev Encodes interest differential, yield shift rewards, and total rewards
     * @param interestDifferential Interest rate differential between EUR and USD
     * @param yieldShiftRewards Rewards from yield shifting operations
     * @param totalRewards Total rewards accumulated
     * @return Packed data as bytes32
     * @custom:security No security implications - pure data packing function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function packRewardData(
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    ) external pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(interestDifferential)) << 128) |
            (uint256(uint64(yieldShiftRewards)) << 64) |
            uint256(uint64(totalRewards))
        );
    }
    
    // =============================================================================
    // VALIDATION FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Validates that the caller has the required role
     * @dev Internal function to check role-based access control
     * @param role The role to validate against
     * @param contractInstance The contract instance to check roles on
     * @custom:security Prevents unauthorized access to protected functions
     * @custom:validation Ensures proper role-based access control
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors Throws NotAuthorized if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access External function with role validation
     * @custom:oracle No oracle dependencies
     */
    function validateRole(bytes32 role, address contractInstance) external view {
        AccessControlUpgradeable accessControl = AccessControlUpgradeable(contractInstance);
        
        if (!accessControl.hasRole(role, msg.sender)) {
            revert ErrorLibrary.NotAuthorized();
        }
    }
    
    /**
     * @notice Validates that closing a position won't cause protocol undercollateralization
     * @dev Checks if closing the position would make the protocol undercollateralized for QEURO minting
     * @param positionMargin The margin amount of the position being closed
     * @param vaultAddress Address of the vault contract
     * @return isValid True if position can be safely closed
     * @custom:security Prevents protocol undercollateralization from position closures
     * @custom:validation Ensures protocol remains properly collateralized
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns boolean result
     * @custom:reentrancy Not applicable - view function
     * @custom:access External function
     * @custom:oracle No oracle dependencies
     */
    function validatePositionClosureSafety(
        uint256 positionMargin,
        address vaultAddress
    ) external view returns (bool isValid) {
        // Skip validation if vault is not set (for backward compatibility)
        if (vaultAddress == address(0)) {
            return true;
        }

        // Get current protocol collateralization status
        (bool success1, bytes memory data1) = vaultAddress.staticcall(
            abi.encodeWithSelector(0xad953caa) // isProtocolCollateralized()
        );
        if (!success1 || data1.length < 64) return false;
        
        (bool isCollateralized, uint256 currentTotalMargin) = abi.decode(data1, (bool, uint256));
        
        // Additional safety check: ensure protocol is currently collateralized
        if (!isCollateralized) return false;
        
        // Get minimum collateralization ratio for minting
        (bool success2, bytes memory data2) = vaultAddress.staticcall(
            abi.encodeWithSelector(0x9aeb7e07) // minCollateralizationRatioForMinting()
        );
        if (!success2 || data2.length < 32) return false;
        uint256 minCollateralizationRatio = abi.decode(data2, (uint256));
        
        // Get QEURO total supply to check if any QEURO has been minted
        (bool success3, bytes memory data3) = vaultAddress.staticcall(
            abi.encodeWithSelector(0xc74ab303) // qeuro()
        );
        if (!success3 || data3.length < 32) return false;
        address qeuroAddress = abi.decode(data3, (address));
        
        uint256 totalQEURO = 0;
        if (qeuroAddress != address(0)) {
            // Call totalSupply on the QEURO contract
            (bool success4, bytes memory data4) = qeuroAddress.staticcall(
                abi.encodeWithSelector(0x18160ddd) // totalSupply()
            );
            if (success4 && data4.length >= 32) {
                totalQEURO = abi.decode(data4, (uint256));
            }
        }

        // If no QEURO has been minted, position can always be closed
        if (totalQEURO == 0) {
            return true;
        }

        // Get UserPool total deposits
        (bool success5, bytes memory data5) = vaultAddress.staticcall(
            abi.encodeWithSelector(0x1adc6930) // userPool()
        );
        if (!success5 || data5.length < 32) return false;
        address userPoolAddress = abi.decode(data5, (address));
        
        uint256 userDeposits = 0;
        if (userPoolAddress != address(0)) {
            // Call totalDeposits on the UserPool contract
            (bool success6, bytes memory data6) = userPoolAddress.staticcall(
                abi.encodeWithSelector(0x7d882097) // totalDeposits()
            );
            if (success6 && data6.length >= 32) {
                userDeposits = abi.decode(data6, (uint256));
            }
        }
        
        // Calculate what the collateralization ratio would be after closing this position
        uint256 remainingHedgerMargin = currentTotalMargin - positionMargin;
        
        // If no user deposits, hedger margin is the only collateral
        if (userDeposits == 0) {
            // If no QEURO has been minted and no user deposits, position can always be closed
            // because there's nothing to hedge
            return true;
        }

        // Calculate future collateralization ratio
        uint256 futureRatio = ((userDeposits + remainingHedgerMargin) * 10000) / userDeposits;

        // Check if closing would make the protocol undercollateralized for minting
        return futureRatio >= minCollateralizationRatio;
    }
    
    // =============================================================================
    // POSITION MANAGEMENT FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Removes a position from the hedger's position arrays
     * @dev Internal function to maintain position tracking arrays
     * @param hedger Address of the hedger whose position to remove
     * @param positionId ID of the position to remove
     * @param hedgerHasPosition Mapping of hedger to position existence
     * @param positionIndex Mapping of hedger to position index
     * @param positionIds Array of position IDs for the hedger
     * @return success True if position was successfully removed
     * @custom:security Maintains data integrity of position tracking arrays
     * @custom:validation Ensures position exists before removal
     * @custom:state-changes Modifies storage mappings and arrays
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns boolean result
     * @custom:reentrancy Not applicable - no external calls
     * @custom:access External function
     * @custom:oracle No oracle dependencies
     */
    function removePositionFromArrays(
        address hedger,
        uint256 positionId,
        mapping(address => mapping(uint256 => bool)) storage hedgerHasPosition,
        mapping(address => mapping(uint256 => uint256)) storage positionIndex,
        uint256[] storage positionIds
    ) external returns (bool success) {
        if (!hedgerHasPosition[hedger][positionId]) {
            return false;
        }
        
        uint256 index = positionIndex[hedger][positionId];
        uint256 lastIndex = positionIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastPositionId = positionIds[lastIndex];
            positionIds[index] = lastPositionId;
            positionIndex[hedger][lastPositionId] = index;
        }
        
        positionIds.pop();
        
        delete positionIndex[hedger][positionId];
        delete hedgerHasPosition[hedger][positionId];
        
        return true;
    }
    
    // =============================================================================
    // ORACLE FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Gets a valid EUR/USD price from the oracle
     * @dev Retrieves and validates price data from the oracle contract
     * @param oracleAddress Address of the oracle contract
     * @return price Valid EUR/USD price from oracle
     * @return isValid True if price is valid
     * @custom:security Ensures oracle price data is valid before use
     * @custom:validation Validates oracle response format and data
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns boolean result
     * @custom:reentrancy Not applicable - view function
     * @custom:access External function
     * @custom:oracle Depends on oracle contract for price data
     */
    function getValidOraclePrice(address oracleAddress) external view returns (uint256 price, bool isValid) {
        (bool success, bytes memory data) = oracleAddress.staticcall(
            abi.encodeWithSelector(0x7feb1d8a) // getEurUsdPrice()
        );
        
        if (!success || data.length < 64) {
            return (0, false);
        }
        
        (price, isValid) = abi.decode(data, (uint256, bool));
        return (price, isValid);
    }
}
