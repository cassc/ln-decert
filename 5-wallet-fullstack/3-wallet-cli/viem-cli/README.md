# Viem Wallet CLI

A TypeScript command-line wallet built with [Viem](https://viem.sh/) for interacting with ERC20 tokens on the Sepolia test network. The CLI can generate a wallet, inspect balances, prepare an ERC20 transfer as an EIP-1559 transaction, sign it with the stored key, and broadcast it to the network.

## Prerequisites
- Node.js 18+
- An RPC endpoint for Sepolia (e.g. Infura, Alchemy, or your own node)
- The address of the ERC20 token you want to transfer

## Setup
1. Install dependencies:
   ```bash
   pnpm install
   ```
2. Configure environment variables:
   ```bash
   cp .env.example .env
   # edit .env with your RPC URL and token address
   ```
3. Build the CLI (optional – `ts-node` can run it directly during development):
   ```bash
   pnpm build
   ```

## Running the CLI
During development you can run the CLI via `ts-node`:
```bash
pnpm dev -- <command> [options]
```

After building you can use the compiled binary:
```bash
pnpm build
node dist/cli.js <command> [options]
```

To install the CLI globally from this workspace:
```bash
pnpm add --global .
viem-wallet <command> [options]
```

## Commands
### `generate`
Generate a new wallet and store it locally.
```bash
viem-wallet generate [--force]
```
- Prints the generated address and private key.
- Stores the wallet JSON at the path defined by `KEYSTORE_PATH` (defaults to `./.wallet.json`).

### `balance`
Display the wallet’s native ETH balance and configured ERC20 balance.
```bash
viem-wallet balance
```
- Requires `SEPOLIA_RPC_URL` and `ERC20_TOKEN_ADDRESS` in your environment.

### `prepare-transfer`
Build an unsigned ERC20 transfer transaction with EIP-1559 parameters.
```bash
viem-wallet prepare-transfer --to <address> --amount <value> [--decimals <n>] [--output prepared.json]
```
- Fetches token metadata (decimals/symbol) when possible.
- Outputs a JSON payload with the populated transaction request suitable for signing.

### `sign`
Sign a prepared transaction using the stored wallet.
```bash
viem-wallet sign --file prepared.json
# or
viem-wallet sign --json '{"request":{...}}'
```
- Produces the signed transaction and its hash in JSON form.

### `send`
Broadcast a signed transaction to Sepolia.
```bash
viem-wallet send --file signed.json [--wait]
```
- Accepts either the JSON created by `sign` or a raw signed transaction hex string.
- Optionally waits for the transaction receipt.

## Workflow Example
```bash
viem-wallet generate
viem-wallet balance
viem-wallet prepare-transfer --to 0xRecipient --amount 1 --output prepared.json
viem-wallet sign --file prepared.json > signed.json
viem-wallet send --file signed.json --wait
```

## Funding Your Wallet
You must manually fund the generated wallet on Sepolia. You can request test ETH from faucets such as:
- https://www.alchemy.com/faucets/ethereum-sepolia
- https://faucet.quicknode.com/ethereum/sepolia

## Security Notes
- The generated private key is stored unencrypted for simplicity. Treat the `.wallet.json` file and console output with care.
- Use this CLI only on test networks unless you add proper key management and safety checks.
