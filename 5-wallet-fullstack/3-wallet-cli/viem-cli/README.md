# Demo


```bash
❯ viem-wallet generate

# Fund the generated wallet with some test ether and ERC20 token
❯ viem-wallet balance

❯ pnpm build

❯ pnpm add --global .

❯ viem-wallet prepare-transfer --to 0xbfDB175c3A4AD1965d2137a18B88a63e16A38
426 --amount 0.999898 --decimals 18 --output prepared.json --password 123
Prepared transaction saved to prepared.json

❯ viem-wallet sign --file prepared.json --password 123
{
  "signedTransaction": "0x02f8b083aa36a780830f4240830f4290828b52944af5347243f5845cfe7a102e651e661ec1ce743780b844a9059cbb000000000000000000000000bfdb175c3a4ad1965d2137a18b88a63e16a384260000000000000000000000000000000000000000000000000de059eeed9fa000c080a08c89bf36e9a8ba6649f75a7de4401ff447a4595187374a4822670f962f998307a05f82639c964a9154f0a9bb73bdaceb2d2ed9ca0e873bb05ed8af64a35b5bcb90",
  "txHash": "0xf18415705e89629d91e8a974d7569b5f7c08bab88ccd028814664d95ded60a96"
}

❯ viem-wallet send --file signed.json --wait
Transaction broadcasted. Hash: 0xf18415705e89629d91e8a974d7569b5f7c08bab88ccd028814664d95ded60a96
Explorer: https://sepolia.etherscan.io/tx/0xf18415705e89629d91e8a974d7569b5f7c08bab88ccd028814664d95ded60a96
Waiting for 1 confirmation...
Status: success
Block number: 9332603
```




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
viem-wallet generate [--force] [--password <password>]
```
- Prints the generated address. The private key is only displayed when no password is supplied.
- Stores the wallet JSON at the path defined by `KEYSTORE_PATH` (defaults to `./.wallet.json`).
- When `--password` is provided the wallet file is encrypted and the same password is required for future operations.

### `balance`
Display the wallet’s native ETH balance and configured ERC20 balance.
```bash
viem-wallet balance [--password <password>]
```
- Requires `SEPOLIA_RPC_URL` and `ERC20_TOKEN_ADDRESS` in your environment.
- Supply `--password` if the wallet was generated with a password.

### `prepare-transfer`
Build an unsigned ERC20 transfer transaction with EIP-1559 parameters.
```bash
viem-wallet prepare-transfer --to <address> --amount <value> [--decimals <n>] [--output prepared.json] [--password <password>]
```
- Fetches token metadata (decimals/symbol) when possible.
- Outputs a JSON payload with the populated transaction request suitable for signing.
- Supply `--password` if the wallet was generated with a password.

### `sign`
Sign a prepared transaction using the stored wallet.
```bash
viem-wallet sign --file prepared.json [--output signed.json] [--password <password>]
# or
viem-wallet sign --json '{"request":{...}}' [--output signed.json] [--password <password>]
```
- Produces the signed transaction and its hash in JSON form.
- Saves to `signed.json` by default, or specify a different file with `--output`.
- Supply `--password` if the wallet was generated with a password.

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
viem-wallet sign --file prepared.json --output signed.json
viem-wallet send --file signed.json --wait
```

## Funding Your Wallet
You must manually fund the generated wallet on Sepolia. You can request test ETH from faucets such as:
- https://cloud.google.com/application/web3/faucet/ethereum/sepolia

## Security Notes
- Generate without `--password` only when you are comfortable storing the private key in plaintext. Treat the `.wallet.json` file and console output with care.
- When using `--password`, remember that losing the password means the wallet cannot be recovered.
