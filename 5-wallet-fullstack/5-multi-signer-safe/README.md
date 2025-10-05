# Multi-Signature Wallet (MultiSigWallet)

A simple on-chain multi-signature wallet implementation using Foundry. This wallet allows multiple owners to collectively manage funds, requiring a minimum number of confirmations before executing transactions.

## Features

- **Multiple Owners**: Define multiple wallet owners during deployment
- **Configurable Threshold**: Set the minimum number of confirmations required
- **On-Chain Proposals**: Transaction proposals are stored directly on-chain
- **Transparent Confirmations**: All confirmations are tracked on-chain via transactions
- **Flexible Execution**: Anyone can execute a transaction once it reaches the threshold
- **Revocable Confirmations**: Owners can revoke their confirmations before execution

## Architecture

Unlike Safe (Gnosis Safe) which uses off-chain signatures, this implementation stores all proposals and confirmations on-chain:

## Contract Functions

### Core Functions

- `submitTransaction(address to, uint256 value, bytes data)` - Submit a new transaction proposal (owners only)
- `confirmTransaction(uint256 txId)` - Confirm a transaction (owners only)
- `executeTransaction(uint256 txId)` - Execute a transaction with enough confirmations (anyone)
- `revokeConfirmation(uint256 txId)` - Revoke a confirmation (owners only)

### View Functions

- `getOwners()` - Get list of all owners
- `getTransactionCount()` - Get total number of transactions
- `getTransaction(uint256 txId)` - Get transaction details
- `isOwner(address)` - Check if address is an owner
- `isConfirmed(uint256 txId, address owner)` - Check if owner confirmed a transaction

## Installation

```bash
# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report
```

## Testing


Run tests:
```bash
forge test -vv
```

## Deployment

### Local/Testnet Deployment

1. Set up your `.env` file:
```bash
PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
```

2. Edit [script/DeployMultiSigWallet.s.sol](script/DeployMultiSigWallet.s.sol) to set your desired owners and threshold

3. Deploy:
```bash
# Deploy to local anvil
forge script script/DeployMultiSigWallet.s.sol:DeployMultiSigWallet --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet (e.g., Sepolia)
forge script script/DeployMultiSigWallet.s.sol:DeployMultiSigWallet --rpc-url $RPC_URL --broadcast --verify
```

## Usage Examples

### Using Foundry Scripts

The [script/InteractWithWallet.s.sol](script/InteractWithWallet.s.sol) provides helper functions:

```bash
# Get wallet info
forge script script/InteractWithWallet.s.sol:InteractWithWallet \
  --sig "getWalletInfo(address)" <WALLET_ADDRESS> \
  --rpc-url $RPC_URL

# Submit a transaction (must be called by an owner)
forge script script/InteractWithWallet.s.sol:InteractWithWallet \
  --sig "submitTx(address,address,uint256)" <WALLET_ADDRESS> <RECIPIENT> <AMOUNT_IN_WEI> \
  --rpc-url $RPC_URL --broadcast --private-key $OWNER1_PRIVATE_KEY

# Confirm a transaction (must be called by an owner)
forge script script/InteractWithWallet.s.sol:InteractWithWallet \
  --sig "confirmTx(address,uint256)" <WALLET_ADDRESS> <TX_ID> \
  --rpc-url $RPC_URL --broadcast --private-key $OWNER2_PRIVATE_KEY

# Execute a transaction (can be called by anyone)
forge script script/InteractWithWallet.s.sol:InteractWithWallet \
  --sig "executeTx(address,uint256)" <WALLET_ADDRESS> <TX_ID> \
  --rpc-url $RPC_URL --broadcast

# Get transaction info
forge script script/InteractWithWallet.s.sol:InteractWithWallet \
  --sig "getTxInfo(address,uint256)" <WALLET_ADDRESS> <TX_ID> \
  --rpc-url $RPC_URL
```

### Using Cast

```bash
# Submit transaction
cast send <WALLET_ADDRESS> "submitTransaction(address,uint256,bytes)" <RECIPIENT> <AMOUNT> "0x" --private-key $OWNER1_KEY

# Confirm transaction
cast send <WALLET_ADDRESS> "confirmTransaction(uint256)" <TX_ID> --private-key $OWNER2_KEY

# Execute transaction
cast send <WALLET_ADDRESS> "executeTransaction(uint256)" <TX_ID> --private-key $ANY_KEY

# Check transaction details
cast call <WALLET_ADDRESS> "getTransaction(uint256)" <TX_ID>
```


## Gas Optimization Notes

This implementation prioritizes simplicity and security over gas optimization. For production use with high transaction volumes, consider:

- Off-chain signature aggregation (like Safe)
- Batch confirmation support
- Optimized storage patterns
