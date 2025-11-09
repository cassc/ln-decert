# Flashbots OpenspaceNFT bundle

This project shows how to deploy the `OpenspaceNFT` contract to Sepolia with Foundry and how to bundle the `enablePresale` and `presale` calls through the Flashbots relay.

## Requirements

- Foundry (`forge`, `cast`)
- pnpm 
- Sepolia RPC URL
- Two funded Sepolia wallets (owner and buyer)
- One key for the Flashbots auth signer (no funds needed)

## Install deps

```bash
pnpm install
forge install
```

## Env vars

Copy `.env.example` to `.env` and fill these values:

- `SEPOLIA_RPC_URL`
- `OWNER_PRIVATE_KEY` private key of the contract owner, by default it's the deployer
- `BUYER_PRIVATE_KEY` private key of the NFT buyer
- `FLASHBOTS_SIGNER_KEY` any key is fine; it never spends ETH and only signs bundle metadata
- `CONTRACT_ADDRESS` the address of the demo OpenspaceNFT contract. Deploy it first if you don't have one.
- `BUNDLE_BLOCKS_AHEAD` how many future blocks (attempts) to target with the same bundle
- `FLASHBOTS_RELAY_URL` optional override for the Flashbots relay RPC (defaults to Sepolia relay)
- `FLASHBOTS_STATUS_URL` optional base URL for monitoring bundle hashes (defaults to Flashbots Protect Sepolia)
- optional gas and bundle tuning values


## Deploy OpenspaceNFT contract

```bash
forge build
forge script script/DeployOpenspaceNFT.s.sol \
  --fork-url $SEPOLIA_RPC_URL \
  --account $DEPLOYER_ACCOUNT \
  --broadcast \
  --verify --verifier blockscout  --verifier-url https://eth-sepolia.blockscout.com/api # optional
```


## Run Flashbots bundle

```bash
pnpm bundle
```

The script will:

1. Owner wallet signs `enablePresale`, buyer wallet signs `presale`; both happen offline.
2. Simulate them on Flashbots.
3. Submit the bundle with `mev_sendBundle` and allow the relay to queue multiple blocks.
4. Wait for inclusion and call `flashbots_getBundleStatsV2`.
5. Print the two tx hashes, the inclusion block, and the stats blob.

### Bundle troubleshooting

- If the script ends after the final attempt with `Bundle not included`, Flashbots never landed the bundle and nothing touched the public mempool.
- Try again with higher gas (raise `MAX_FEE_PER_GAS_GWEI` or `MAX_PRIORITY_FEE_PER_GAS_GWEI`) or allow more attempts (`BUNDLE_BLOCKS_AHEAD=3` or `4`).
- You can also re-run immediately; each run signs fresh txs and sends a new bundle.

### When Sepolia relay is stuck

The public Sepolia Flashbots relay often refuses to land bundles and hides the stats RPC. If you need working bundles:

- Use the main Flashbots relay on Ethereum mainnet: https://relay.flashbots.net
- Send private transactions through Flashbots Protect instead of bundles: https://docs.flashbots.net/flashbots-protect/rpc/quick-start
- Run your own builder + relay locally together with Anvil so every bundle lands in your fork: https://github.com/flashbots/builder
- Try other builder networks such as bloXroute (https://docs.bloxroute.com/), Manifold (https://docs.manifoldfinance.com/), or Beaverbuild (https://relay.beaverbuild.org/) that expose bundle APIs
