// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockAggregatorV3
 * @notice Mock Chainlink price feed for testing
 * @dev Implements AggregatorV3Interface with configurable behavior to simulate:
 *      - Price updates with variable decimals
 *      - Revert scenarios and invalid price outputs
 *      - Stale timestamps and round progression
 * @custom:security-contact team@quantillon.money
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public price;
    uint8 public decimals_;
    uint256 public updatedAt;
    bool public shouldRevert;
    bool public shouldReturnInvalidPrice;
    uint80 public roundId = 1;

    /**
     * @notice Constructor for MockPriceFeed
     * @dev Mock function for testing purposes
     * @param _decimals The number of decimals for the price feed
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Initializes decimals and updatedAt timestamp
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    constructor(uint8 _decimals) {
        decimals_ = _decimals;
        updatedAt = block.timestamp;
    }

    /**
     * @notice Sets the price for the mock price feed
     * @dev Mock function for testing purposes
     * @param _price The price to set
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates price and increments roundId
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function setPrice(int256 _price) external {
        price = _price;
        roundId++;
    }

    /**
     * @notice Sets whether the mock price feed should revert
     * @dev Mock function for testing purposes
     * @param _shouldRevert Whether the price feed should revert
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates shouldRevert flag
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    /**
     * @notice Sets whether the mock price feed should return invalid price
     * @dev Mock function for testing purposes
     * @param _shouldReturnInvalidPrice Whether the price feed should return invalid price
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates shouldReturnInvalidPrice flag
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function setShouldReturnInvalidPrice(bool _shouldReturnInvalidPrice) external {
        shouldReturnInvalidPrice = _shouldReturnInvalidPrice;
    }

    /**
     * @notice Sets the updated timestamp for the mock price feed
     * @dev Test helper function to control price feed timestamps
     * @param _updatedAt The timestamp to set as the last update time
     * @custom:security No security implications - test helper function
     * @custom:validation No input validation required - test helper
     * @custom:state-changes Updates the updatedAt timestamp for testing
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - simple state update
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependency - mock function
     */
    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    /**
     * @notice Returns the latest round data for the mock price feed
     * @dev Mock implementation of Chainlink's latestRoundData function for testing
     * @return _roundId The round ID
     * @return _answer The price answer
     * @return _startedAt The timestamp when the round started
     * @return _updatedAt The timestamp when the round was last updated
     * @return _answeredInRound The round ID in which the answer was computed
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function latestRoundData() external view returns (
        uint80 _roundId,
        int256 _answer,
        uint256 _startedAt,
        uint256 _updatedAt,
        uint80 _answeredInRound
    ) {
        if (shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }

        if (shouldReturnInvalidPrice) {
            return (_roundId, -1, 0, _updatedAt, _roundId);
        }

        return (roundId, price, 0, updatedAt, roundId);
    }

    /**
     * @notice Gets round data for the mock price feed
     * @dev Mock function for testing purposes
     * @return _roundId The round ID
     * @return _answer The price answer
     * @return _startedAt The timestamp when the round started
     * @return _updatedAt The timestamp when the round was updated
     * @return _answeredInRound The round ID when the answer was provided
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors Throws "MockAggregator: Simulated failure" if shouldRevert is true
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function getRoundData(uint80 /* _id */) 
        external 
        view 
        returns (
            uint80 _roundId,
            int256 _answer,
            uint256 _startedAt,
            uint256 _updatedAt,
            uint80 _answeredInRound
        )
    {
        if (shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }

        if (shouldReturnInvalidPrice) {
            return (_roundId, -1, 0, _updatedAt, _roundId);
        }

        return (_roundId, price, 0, _updatedAt, _roundId);
    }

    /**
     * @notice Gets the number of decimals for the mock price feed
     * @dev Mock function for testing purposes
     * @return The number of decimals
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function decimals() external view returns (uint8) {
        return decimals_;
    }

    /**
     * @notice Gets the description of the mock price feed
     * @dev Mock function for testing purposes
     * @return The description string
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function description() external pure returns (string memory) {
        return "Mock Price Feed";
    }

    /**
     * @notice Gets the version of the mock price feed
     * @dev Mock function for testing purposes
     * @return The version number
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function version() external pure returns (uint256) {
        return 1;
    }
}
