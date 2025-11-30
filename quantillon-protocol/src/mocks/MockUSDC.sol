// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing and development
 * @notice This is a simplified ERC20 token that mimics USDC behavior
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private constant _DECIMALS = 6;
    
    constructor() ERC20("USD Coin", "USDC") Ownable(msg.sender) {
        // Mint initial supply to deployer
        uint256 initialSupply = 1_000_000 * 10**_DECIMALS; // 1M USDC
        _mint(msg.sender, initialSupply);
    }
    
    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }
    
    /**
     * @dev Mint tokens to a specific address (for testing)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Faucet function for easy testing - anyone can call this
     * @param amount The amount of tokens to mint to caller
     */
    function faucet(uint256 amount) external {
        require(amount <= 1000 * 10**_DECIMALS, "MockUSDC: Faucet limit exceeded");
        _mint(msg.sender, amount);
    }
}
