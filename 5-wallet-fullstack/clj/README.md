# Wallet CLI

This small Clojure tool lets you:

- create a fresh private key and store it locally
- check ETH and ERC20 balance through an RPC URL
- build and sign an ERC20 EIP-1559 transfer and optionally send it to Sepolia

## Prerequisites

- Java 11+
- [Clojure CLI](https://clojure.org/guides/getting_started#_clojure_installer_and_cli_tools)
- an Ethereum RPC URL (for example Infura or Alchemy Sepolia endpoint)

## Install deps

```bash
clojure -P
```

## Generate a key

```bash
clojure -M -m wallet.core keygen --out wallet-account.json
```

Add `--password my-secret` to create an encrypted keystore instead of a plain JSON file. The password is required to sign transactions.

## Check balance

```bash
clojure -M -m wallet.core balance \
  --rpc https://sepolia.infura.io/v3/YOUR_PROJECT \
  --address 0xYourAddress \
  --token 0xTokenContract
```

Add `--decimals` when the token has non-standard decimals.

## Create, sign, and send a transfer

```bash
clojure -M -m wallet.core transfer \
  --rpc https://sepolia.infura.io/v3/YOUR_PROJECT \
  --key-file wallet-account.json \
  --token 0xTokenContract \
  --to 0xRecipient \
  --amount 10 \
  --send
```

The tool fetches nonce, gas data, builds an EIP-1559 transaction, signs it with the key from the JSON file, and sends it to Sepolia. Remove `--send` when you only need the signed raw transaction hex.

Use `--password` when your key file is encrypted.

## Notes

- Default chain id is 11155111 (Sepolia). Override with `--chain-id` when needed.
- Use `--max-priority` and `--max-fee` (in gwei) to set custom gas fees.
- Keep the generated private key safe. Use `--password` when you want an encrypted keystore file.
