# Sepolia Deployment (Foundry)

This folder contains a minimal Foundry project for deploying and verifying the `MyToken` ERC20 contract on Sepolia.

## Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed (`foundryup`)
- A funded Sepolia account whose private key you control
- An Etherscan API key with Sepolia access

## Install dependencies
```sh
forge install
```

## Configure environment
Set the following environment variables before running scripts (adjust values as needed):
```sh
export SEPOLIA_RPC_URL="https://YOUR_RPC_ENDPOINT"
export PRIVATE_KEY="0xyourprivatekey"
export ETHERSCAN_API_KEY="your-etherscan-api-key"
export TOKEN_NAME="My Token"
export TOKEN_SYMBOL="MYT"
```
`TOKEN_NAME` and `TOKEN_SYMBOL` are optional—defaults defined in the script are used if you omit them.

## Build
```sh
forge build
```

## Dry-run deployment
```sh
forge script script/DeployMyToken.s.sol:DeployMyToken  --rpc-url https://eth-sepolia.public.blastapi.io 
  ```


## Deploy to Sepolia
```sh
forge script script/DeployMyToken.s.sol:DeployMyToken \
  --rpc-url  https://eth-sepolia.public.blastapi.io  \
  --broadcast \
  --verify \
  --account optional-metamask-account \
  --etherscan-api-key $ETHERSCAN_API_KEY
```
The script automatically picks up `PRIVATE_KEY` for signing. After a successful run, Foundry prints the deployed `MyToken` address.


