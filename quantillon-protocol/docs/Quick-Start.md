# Quantillon Protocol Quick Start

Signed quotes are active on Base since **17 October 2026**. Normal mint and redemption must use `executeWithQuote(bytes,bytes)` on the authorized Vault or UserPool target. Bare conversion calls and the legacy pricing module's previews are not the current integration path.

This **ethers v6** example uses the UserPool conversion route. It does not use UserPool's optional staking accounting. The later staking example deposits QEURO directly into the ERC-4626 series. Use the [address inventory](API-Reference.md) and [production guide](Signed-Quote-Migration.md), and test with an isolated fork before integration.

## Connect and pin the intended deployment

```javascript
import { BrowserProvider, Contract, Interface, keccak256, parseUnits, ZeroAddress } from 'ethers';

const provider = new BrowserProvider(window.ethereum);
if ((await provider.getNetwork()).chainId !== 8453n) throw new Error('Select Base');
const signer = await provider.getSigner();
const owner = await signer.getAddress();
const vaultAddress = '0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07';
const poolAddress = '0x712bCc77e7aa53C79870A40d044D440Ad2901bF2';
const moduleAddress = '0x076F86a591258957665b65c04F04B706D00EaEBa';
const qeuroAddress = '0x69aD4e6c49d6275D0e11b5515D98a89f029869AA';
const usdcAddress = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
const factoryAddress = '0x0382B0b9FB6Ff737209C3B31D727BB9d2E2bcb53';
const tokenAbi = [
  'function approve(address spender,uint256 amount) returns (bool)',
  'function balanceOf(address owner) view returns (uint256)',
];
const usdc = new Contract(usdcAddress, tokenAbi, signer);
const qeuro = new Contract(qeuroAddress, tokenAbi, signer);
const vault = new Contract(vaultAddress, [
  'function executionPricing() view returns (address)',
  'function signedExecutionEnabled() view returns (bool)',
], provider);
const pool = new Contract(poolAddress, [
  'function executeWithQuote(bytes callData,bytes authorization) returns (bytes)',
], signer);
const route = new Interface([
  'function deposit(uint256[] amounts,uint256[] minimums)',
  'function withdraw(uint256[] amounts,uint256[] minimums)',
]);
```

## Approval, quote and review

For a mint, approve USDC to the selected target **before** requesting an executable quote:

```javascript
const inputUsdc = parseUnits('100', 6); // illustrative user-selected amount
await (await usdc.approve(poolAddress, inputUsdc)).wait();
```

The dapp's authenticated gateway accepts `POST /api/quotes` with a JSON body such as `{"action":"MINT","amountIn":"100000000","chainId":8453,"route":"USER_POOL"}` and the wallet identity associated with the authenticated session. The frontend supplies `credentials: 'include'` and `x-wallet-address`; a header alone does not establish a login session. Integrators must arrange access to the quote service. `POST /api/quotes/preview` returns a preview, not an executable authorization.

An executable envelope contains `chainId`, `module`, `target`, `callData`, `authorization` and a `quote` with wallet/caller, action, exact input/output, observation time, validity times, nonce, epoch and hashes. Display the output and deadline for user review. Use integer base units: USDC has 6 decimals and QEURO has 18.

## Submit the reviewed UserPool quote

The function below accepts an envelope already obtained from the quote service, plus the exact action, input and output reviewed by the user. It checks the deployment and allowed inner call before sending anything. The contract validates the signatures and remaining protocol guards.

```javascript
async function settleReviewedPoolQuote(envelope, reviewed) {
  const same = (a, b) => a.toLowerCase() === b.toLowerCase();
  if (!['MINT', 'REDEEM'].includes(reviewed.action)) throw new Error('Invalid action');
  if (reviewed.amountIn <= 0n || reviewed.amountOut <= 0n) throw new Error('Invalid amount');
  if ((await provider.getNetwork()).chainId !== 8453n ||
      !same(await signer.getAddress(), owner)) throw new Error('Wallet or chain changed');
  if (!await vault.signedExecutionEnabled() ||
      !same(await vault.executionPricing(), moduleAddress)) throw new Error('Deployment changed');
  const q = envelope.quote;
  const action = reviewed.action === 'MINT' ? 0 : 1;
  const functionName = action === 0 ? 'deposit' : 'withdraw';
  const expectedCall = route.encodeFunctionData(functionName, [
    [reviewed.amountIn], [reviewed.amountOut],
  ]);
  if (envelope.chainId !== 8453 || !same(envelope.target, poolAddress) ||
      !same(envelope.module, moduleAddress) || !same(q.user, owner) ||
      !same(q.caller, poolAddress) || q.action !== action ||
      BigInt(q.amountIn) !== reviewed.amountIn || BigInt(q.amountOut) !== reviewed.amountOut ||
      envelope.callData.toLowerCase() !== expectedCall.toLowerCase() ||
      q.callHash.toLowerCase() !== keccak256(envelope.callData).toLowerCase()) {
    throw new Error('Quote differs from the reviewed operation');
  }
  const checkTime = () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    if (BigInt(q.validAfter) > now || BigInt(q.observedAt) > now ||
        BigInt(q.validUntil) < now + 10n ||
        BigInt(q.validUntil) - BigInt(q.observedAt) > 45n) {
      throw new Error('Request and review a fresh quote');
    }
  };
  checkTime();
  await pool.executeWithQuote.staticCall(envelope.callData, envelope.authorization);
  checkTime();
  const tx = await pool.executeWithQuote(envelope.callData, envelope.authorization);
  // Persist tx.hash immediately; reconcile its receipt before any retry.
  return tx;
}
```

The 10-second remaining-time check is a client convenience, not an inclusion guarantee. The onchain maximum is **45 seconds from the market observation**. Simulation does not reserve public liquidity, and state changes or wallet delays can still cause a revert. Never modify the signed calldata or silently refresh the user's accepted output.

## Stake QEURO directly

```javascript
const factory = new Contract(factoryAddress, [
  'function getStQEUROByVaultId(uint256 vaultId) view returns (address)',
], provider);
const seriesAddress = await factory.getStQEUROByVaultId(2n);
if (seriesAddress === ZeroAddress) throw new Error('No staking series');
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

Standard ERC-4626 `deposit` does not accept a minimum-share argument: a preview is informational, not slippage protection. The vault's signed `mintAndStakeQEURO` inner operation has an explicit minimum-share parameter for a combined mint/stake. Yield increases the assets represented by shares as it vests; no separate staking-reward claim is needed. See [Yield Distribution 1.5.0](Yield-Distribution-1.5.0.md).

## Next steps

[Integration Examples](Integration-Examples.md) covers redemption, unstaking and transaction recovery. [Dapp Compatibility](Dapp-Compatibility.md) lists release checks. Use the compiled ABI matching each active implementation, including library errors.
