# MockUSDC
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/84573e20d663003e9e5ffbb3e1ac29ca4b399f78/src/mocks/MockUSDC.sol)

**Inherits:**
ERC20, Ownable

This is a simplified ERC20 token that mimics USDC behavior

*Mock USDC token for testing and development*


## State Variables
### _DECIMALS

```solidity
uint8 private constant _DECIMALS = 6;
```


## Functions
### constructor


```solidity
constructor() ERC20("USD Coin", "USDC") Ownable(msg.sender);
```

### decimals

*Returns the number of decimals used to get its user representation.*


```solidity
function decimals() public pure override returns (uint8);
```

### mint

*Mint tokens to a specific address (for testing)*


```solidity
function mint(address to, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to mint tokens to|
|`amount`|`uint256`|The amount of tokens to mint|


### faucet

*Faucet function for easy testing - anyone can call this*


```solidity
function faucet(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to mint to caller|


