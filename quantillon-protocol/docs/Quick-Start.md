# Quantillon Protocol Quick Start

This example targets the current Base deployment and **ethers v6**, using integer arithmetic and a wallet signer. It mints QEURO and deposits QEURO into the direct ERC-4626 stQEURO series. The optional UserPool contract is a different staking path.

Install `ethers@6` in your integration project. Obtain current ABIs from the compiled `out/<Contract>.sol/<Contract>.json` artifact's `abi` field; signature baseline files are not JSON ABIs. Use the [address inventory](API-Reference.md#contract-addresses) and check [Production Protocol Reference](Production-Protocol-Reference.md) before integrating. Library syntax follows the [ethers v6 guide](https://docs.ethers.org/v6/getting-started/).

## Connect and resolve the active contracts

```javascript
import { BrowserProvider, Contract, parseUnits, ZeroAddress } from 'ethers';

// Browser wallet must be configured for Base. Production server-side reads use
// https://app.quantillon.money/api/rpc/base, not a public Base RPC fallback.
const provider = new BrowserProvider(window.ethereum);
if ((await provider.getNetwork()).chainId !== 8453n) throw new Error('Select Base');
const signer = await provider.getSigner();
const owner = await signer.getAddress();
const vaultAddress = '0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07';
const qeuroAddress = '0x69aD4e6c49d6275D0e11b5515D98a89f029869AA';
const usdcAddress = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
const factoryAddress = '0x0382B0b9FB6Ff737209C3B31D727BB9d2E2bcb53';

const tokenAbi = [
  'function approve(address spender,uint256 amount) returns (bool)',
  'function balanceOf(address owner) view returns (uint256)',
];
const vault = new Contract(vaultAddress, [
  'function executionPricing() view returns (address)',
  'function paused() view returns (bool)',
  'function mintQEURO(uint256 usdcAmount,uint256 minQeuroOut)',
  'function redeemQEURO(uint256 qeuroAmount,uint256 minUsdcOut)',
  'function shouldTriggerLiquidationLive() returns (bool shouldLiquidate,uint256 collateralizationRatio)',
], signer);
const pricingAddress = await vault.executionPricing();
if (pricingAddress === ZeroAddress) throw new Error('No execution pricing configured');
const pricing = new Contract(pricingAddress, [
  'function previewMint(uint256 input) view returns ((uint256 amountOut,uint256 executionRate,uint256 referenceRate,uint256 capacityQeuro,uint256 observedAt,uint256 sequence) quote)',
  'function previewRedeem(uint256 input) view returns ((uint256 amountOut,uint256 executionRate,uint256 referenceRate,uint256 capacityQeuro,uint256 observedAt,uint256 sequence) quote)',
], provider);
const usdc = new Contract(usdcAddress, tokenAbi, signer);
const qeuro = new Contract(qeuroAddress, tokenAbi, signer);
const factory = new Contract(factoryAddress, [
  'function getStQEUROByVaultId(uint256 vaultId) view returns (address)',
], provider);
const seriesAddress = await factory.getStQEUROByVaultId(2n);
if (seriesAddress === ZeroAddress) throw new Error('No series for this vault');
const series = new Contract(seriesAddress, [
  'function asset() view returns (address)',
  'function previewDeposit(uint256 assets) view returns (uint256)',
  'function deposit(uint256 assets,address receiver) returns (uint256)',
  'function balanceOf(address owner) view returns (uint256)',
  'function convertToAssets(uint256 shares) view returns (uint256)',
  'function redeem(uint256 shares,address receiver,address owner) returns (uint256)',
], signer);
if ((await series.asset()).toLowerCase() !== qeuroAddress.toLowerCase()) {
  throw new Error('Unexpected staking asset');
}
const minimum = (output, toleranceBps) => {
  if (toleranceBps < 0n || toleranceBps >= 10_000n) throw new Error('Invalid tolerance');
  return output * (10_000n - toleranceBps) / 10_000n;
};
```

## Mint with a current execution quote

```javascript
if (await vault.paused()) throw new Error('Vault paused');
const inputUsdc = parseUnits('100', 6);
await (await usdc.approve(vaultAddress, inputUsdc)).wait();
// Quote after approval is mined; its amountOut already includes the mint fee.
const quote = await pricing.previewMint(inputUsdc);
const minQeuro = minimum(quote.amountOut, 50n); // illustrative 0.5%; user chooses
await vault.mintQEURO.staticCall(inputUsdc, minQeuro);
await (await vault.mintQEURO(inputUsdc, minQeuro)).wait();
```

Simulation does not reserve capacity. A later state change can make the transaction revert. Do not derive output by dividing USDC by an oracle mid or use the retired `calculateMintAmount` helper.

## Stake QEURO directly

```javascript
const assets = parseUnits('10', 18); // user-selected amount, must be available
if (await qeuro.balanceOf(owner) < assets) throw new Error('Insufficient QEURO');
await (await qeuro.approve(seriesAddress, assets)).wait();
const expectedShares = await series.previewDeposit(assets);
if (expectedShares === 0n) throw new Error('Deposit would produce no shares');
await series.deposit.staticCall(assets, owner);
await (await series.deposit(assets, owner)).wait();
const shares = await series.balanceOf(owner);
const vestedAssets = await series.convertToAssets(shares);
```

Standard ERC-4626 `deposit` does not accept a minimum-share argument: a preview is informational, not slippage protection. The vault's `mintAndStakeQEURO` path has an explicit minimum-share parameter for a combined mint/stake. Yield increases the assets represented by shares as it vests; no separate staking-reward claim is needed. See [Yield Distribution 1.5.0](Yield-Distribution-1.5.0.md).

## Next steps

[Integration Examples](Integration-Examples.md) covers normal redemption, unstaking and transaction recovery. The [API Reference](API-Reference.md) documents optional UserPool, hedger and dormant QTI interfaces. No mainnet transactions are required to validate an integration: use an isolated fork and funded test accounts.
