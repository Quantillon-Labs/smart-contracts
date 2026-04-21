# IstQEURO
**Title:**
IstQEURO

Minimal ERC-4626-oriented interface for stQEURO vault tokens.


## Functions
### asset


```solidity
function asset() external view returns (address);
```

### totalAssets


```solidity
function totalAssets() external view returns (uint256);
```

### convertToShares


```solidity
function convertToShares(uint256 assets) external view returns (uint256 shares);
```

### convertToAssets


```solidity
function convertToAssets(uint256 shares) external view returns (uint256 assets);
```

### previewDeposit


```solidity
function previewDeposit(uint256 assets) external view returns (uint256 shares);
```

### previewMint


```solidity
function previewMint(uint256 shares) external view returns (uint256 assets);
```

### previewWithdraw


```solidity
function previewWithdraw(uint256 assets) external view returns (uint256 shares);
```

### previewRedeem


```solidity
function previewRedeem(uint256 shares) external view returns (uint256 assets);
```

### deposit


```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares);
```

### mint


```solidity
function mint(uint256 shares, address receiver) external returns (uint256 assets);
```

### withdraw


```solidity
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
```

### redeem


```solidity
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
```

### balanceOf


```solidity
function balanceOf(address owner) external view returns (uint256 shares);
```

### totalSupply


```solidity
function totalSupply() external view returns (uint256 sharesSupply);
```

### yieldFee


```solidity
function yieldFee() external view returns (uint256);
```

### updateYieldParameters


```solidity
function updateYieldParameters(uint256 _yieldFee) external;
```

### vaultName


```solidity
function vaultName() external view returns (string memory);
```

