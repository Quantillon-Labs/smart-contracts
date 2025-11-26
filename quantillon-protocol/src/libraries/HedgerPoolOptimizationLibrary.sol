// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HedgerPoolErrorLibrary} from "./HedgerPoolErrorLibrary.sol";
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
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(positionSize, margin, leverage, entryPrice));
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
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(exitPrice, pnl, timestamp));
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
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(marginAmount, newMarginRatio, isAdded));
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
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(liquidationReward, remainingMargin));
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
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(interestDifferential, yieldShiftRewards, totalRewards));
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
            revert HedgerPoolErrorLibrary.NotAuthorized();
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

        // Get protocol data in separate function to reduce stack depth
        (bool isCollateralized, uint256 currentTotalMargin, uint256 minCollateralizationRatio) = _getProtocolData(vaultAddress);
        
        // Additional safety check: ensure protocol is currently collateralized
        if (!isCollateralized) return false;
        
        // Check if QEURO has been minted
        if (!_hasQEUROMinted(vaultAddress)) {
            return true;
        }

        // Get user deposits and validate closure
        return _validateClosureWithUserDeposits(vaultAddress, positionMargin, currentTotalMargin, minCollateralizationRatio);
    }

    /**
     * @notice Gets protocol collateralization data
     * @dev Internal function to reduce stack depth
     * @param vaultAddress Address of the vault contract
     * @return isCollateralized Whether protocol is currently collateralized
     * @return currentTotalMargin Current total margin in the protocol
     * @return minCollateralizationRatio Minimum collateralization ratio for minting
     * @custom:security Uses staticcall for safe external contract interaction
     * @custom:validation Validates call success and data length before decoding
     * @custom:state-changes No state changes, view function
     * @custom:events No events emitted
     * @custom:errors Returns default values on call failures
     * @custom:reentrancy No reentrancy risk, view function
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _getProtocolData(address vaultAddress) internal view returns (bool isCollateralized, uint256 currentTotalMargin, uint256 minCollateralizationRatio) {
        // Get current protocol collateralization status
        (bool success1, bytes memory data1) = vaultAddress.staticcall(
            abi.encodeWithSelector(0xad953caa) // isProtocolCollateralized()
        );
        if (!success1 || data1.length < 64) return (false, 0, 0);
        
        (isCollateralized, currentTotalMargin) = abi.decode(data1, (bool, uint256));
        
        // Get minimum collateralization ratio for minting
        (bool success2, bytes memory data2) = vaultAddress.staticcall(
            abi.encodeWithSelector(0x9aeb7e07) // minCollateralizationRatioForMinting()
        );
        if (!success2 || data2.length < 32) return (false, 0, 0);
        minCollateralizationRatio = abi.decode(data2, (uint256));
    }

    /**
     * @notice Checks if QEURO has been minted
     * @dev Internal function to reduce stack depth
     * @param vaultAddress Address of the vault contract
     * @return hasMinted Whether QEURO has been minted (totalSupply > 0)
     * @custom:security Uses staticcall for safe external contract interaction
     * @custom:validation Validates call success and data length before decoding
     * @custom:state-changes No state changes, view function
     * @custom:events No events emitted
     * @custom:errors Returns false on call failures
     * @custom:reentrancy No reentrancy risk, view function
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _hasQEUROMinted(address vaultAddress) internal view returns (bool hasMinted) {
        // Get QEURO address
        (bool success, bytes memory data) = vaultAddress.staticcall(
            abi.encodeWithSelector(0xc74ab303) // qeuro()
        );
        if (!success || data.length < 32) return false;
        address qeuroAddress = abi.decode(data, (address));
        
        if (qeuroAddress == address(0)) return false;
        
        // Call totalSupply on the QEURO contract
        (bool success2, bytes memory data2) = qeuroAddress.staticcall(
            abi.encodeWithSelector(0x18160ddd) // totalSupply()
        );
        if (!success2 || data2.length < 32) return false;
        uint256 totalQEURO = abi.decode(data2, (uint256));
        
        return totalQEURO > 0;
    }

    /**
     * @notice Validates closure with user deposits
     * @dev Internal function to reduce stack depth
     * @param vaultAddress Address of the vault contract
     * @param positionMargin Margin for the position being closed
     * @param currentTotalMargin Current total margin in the protocol
     * @param minCollateralizationRatio Minimum collateralization ratio for minting
     * @return isValid Whether the position can be safely closed
     * @custom:security Validates protocol remains collateralized after closure
     * @custom:validation Ensures closure doesn't violate collateralization requirements
     * @custom:state-changes No state changes, view function
     * @custom:events No events emitted
     * @custom:errors No custom errors, returns boolean result
     * @custom:reentrancy No reentrancy risk, view function
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _validateClosureWithUserDeposits(
        address vaultAddress,
        uint256 positionMargin,
        uint256 currentTotalMargin,
        uint256 minCollateralizationRatio
    ) internal view returns (bool isValid) {
        // Get UserPool address
        (bool success, bytes memory data) = vaultAddress.staticcall(
            abi.encodeWithSelector(0x1adc6930) // userPool()
        );
        if (!success || data.length < 32) return false;
        address userPoolAddress = abi.decode(data, (address));
        
        // Get user deposits
        uint256 userDeposits = 0;
        if (userPoolAddress != address(0)) {
            (bool success2, bytes memory data2) = userPoolAddress.staticcall(
                abi.encodeWithSelector(0x7d882097) // totalDeposits()
            );
            if (success2 && data2.length >= 32) {
                userDeposits = abi.decode(data2, (uint256));
            }
        }
        
        // If no user deposits, position can always be closed
        if (userDeposits == 0) {
            return true;
        }

        // Calculate remaining margin and future ratio
        uint256 remainingHedgerMargin = currentTotalMargin - positionMargin;
        uint256 futureRatio = ((userDeposits + remainingHedgerMargin) * 10000) / userDeposits;

        return futureRatio >= minCollateralizationRatio;
    }
    
    // =============================================================================
    // POSITION MANAGEMENT FUNCTIONS
    // =============================================================================
    
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
