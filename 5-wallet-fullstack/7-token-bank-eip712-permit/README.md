## Features

NFT contract owner can mint NFTs:

# todo add image here use mint.png

NFT whitelist signer can 

## Permit Token Bank & NFT Market

This workspace contains a Foundry project plus a React front end that demonstrate:

- **PermitToken** – an ERC20 built on OpenZeppelin `ERC20Permit`, used for all deposits and NFT purchases.
- **Bank** – holds user balances in `PermitToken`, supports direct deposits and the new `permitDeposit` path that accepts off-chain EIP‑2612 signatures.
- **PermitNFT** – minimal ERC721 collection the project owner can mint.
- **NFTMarket** – marketplace that only allows `permitBuy` purchases from wallets that present a valid EIP‑712 whitelist signature issued by the project team.

```
├── src/                Solidity contracts (token, bank, NFT, market)
├── test/               Foundry tests covering permit deposit and whitelist buys
├── frontend/           React + wagmi dApp with permit flows
└── lib/openzeppelin-contracts  Local OZ dependency (symlinked)
```

---

### 1. Prerequisites

- Foundry (`forge`, `cast`) installed and set up.
- Node.js ≥ 18.x for the front end.
- Wallet/private key that can deploy contracts and issue whitelist signatures.

---

### 2. Run the Foundry tests

```bash
forge test -vvvv
```

The verbose output includes the `Transfer` events for both token deposits and NFT purchases (see sample trace above).  
Use `forge test --match-contract BankTest` or `--match-contract NFTMarketTest` if you want to scope the suites.

---

### 3. Deploy the contracts

You can deploy everything in one go with the provided Forge script, or run the individual `forge create` commands manually.

#### A. Deploy with `forge script` (recommended)

```bash
export RPC_URL="https://sepolia.infura.io/v3/<YOUR_KEY>"
export ETHERSCAN_API_KEY="..."                 # for --verify (optional but recommended)
export TOKEN_OWNER="0xbfDB175c3A4AD1965d2137a18B88a63e16A38426"
export WHITELIST_SIGNER="0xSignerAddress..."   # wallet that signs permitBuy payloads
export NFT_OWNER="0xOptionalDifferentOwner"    # defaults to TOKEN_OWNER if omitted
export NFT_NAME="Permit NFT"                   # optional
export NFT_SYMBOL="PNFT"                       # optional
```

Then:

```bash
forge script script/DeployPermitSystem.s.sol:DeployPermitSystem \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --account decert \
  -vvvv
```

The script:

- deploys `PermitToken`, `Bank`, `PermitNFT`, and `NFTMarket` using the broadcast account (set via `--account` / `--private-key` / `--ledger`).
- uses the env variables for constructor arguments.
- prints all deployed addresses, and when `--verify` is present Foundry will submit verifications for each contract automatically.

You can omit `--verify` if you only want to deploy.

#### B. Manual `forge create` flow

If you prefer issuing each transaction yourself:

```bash
export RPC_URL="https://sepolia.infura.io/v3/<YOUR_KEY>"
export DEPLOYER_PK="0x..."
export WHITELIST_SIGNER="0x..."   # address whose key will sign permitBuy payloads
```

1. **Deploy PermitToken** (owner receives the initial supply and can mint for demos):
   ```bash
   forge create src/PermitToken.sol:PermitToken \
     --rpc-url "$RPC_URL" \
     --private-key "$DEPLOYER_PK" \
     --constructor-args "$YOUR_OWNER_ADDRESS"
   ```
2. **Deploy Bank** with the token address:
   ```bash
   forge create src/Bank.sol:Bank \
     --rpc-url "$RPC_URL" \
     --private-key "$DEPLOYER_PK" \
     --constructor-args "$PERMIT_TOKEN_ADDRESS"
   ```
3. **Deploy PermitNFT** – pass the NFT owner address, name, and symbol:
   ```bash
   forge create src/PermitNFT.sol:PermitNFT \
     --rpc-url "$RPC_URL" \
     --private-key "$DEPLOYER_PK" \
     --constructor-args "$YOUR_OWNER_ADDRESS" "Permit NFT" "PNFT"
   ```
4. **Deploy NFTMarket** with the token and whitelist signer:
   ```bash
   forge create src/NFTMarket.sol:NFTMarket \
     --rpc-url "$RPC_URL" \
     --private-key "$DEPLOYER_PK" \
     --constructor-args "$PERMIT_TOKEN_ADDRESS" "$WHITELIST_SIGNER"
   ```

Optional: verify each contract with `forge verify-contract`.

After deployment, fund demo accounts with `PermitToken` (the owner can call `mint`), approve the Bank where necessary, and mint NFTs via `PermitNFT.mintTo`.

---

### 4. Issuing whitelist signatures for `permitBuy`

To whitelist a buyer, sign the typed data returned by `NFTMarket.hashPermitBuy`:

```solidity
bytes32 digest = NFTMarket.hashPermitBuy(buyer, nftAddress, tokenId, price, deadline);
```

The signer must be `NFTMarket.whitelistSigner()`. Deliver the resulting signature (65‑byte hex string) to the buyer—they paste it into the front end for `permitBuy`.

---

### 5. Front-end setup

```
cd frontend
cp .env.example .env.local
```

Fill in:

```
VITE_BANK_ADDRESS=0xBank...
VITE_TOKEN_ADDRESS=0xToken...
VITE_NFT_ADDRESS=0xPermitNFT...
VITE_MARKET_ADDRESS=0xMarket...
VITE_WHITELIST_SIGNER=0xSigner...   # optional but keeps the UI in sync
VITE_CHAIN_ID=11155111               # e.g. Sepolia
VITE_CHAIN_NAME=Sepolia Testnet
VITE_RPC_URL=https://1rpc.io/sepolia
```

Install deps and run:

```bash
npm install
npm run dev   # http://localhost:5173
# For production build:
npm run build
```

#### Front-end capabilities

**Permit Deposit (Two-Step Flow)**
- **Step 1 (Signer):** Generate an EIP-2612 permit signature for depositing tokens. The signer doesn't need to execute the transaction themselves—they can share the generated JSON with anyone.
- **Step 2 (Executor):** Anyone can execute the deposit on behalf of the signer by loading the permit JSON and submitting the transaction. The executor pays the gas, but the tokens come from the signer's wallet.

**Other features:**
- Withdraw full token balance from the Bank.
- Mint NFTs (restricted to the contract owner), approve marketplace, and list NFTs with prices in `PermitToken`.
- **Permit Buy (Two-Step Flow):** Whitelist signer generates signatures, and any authorized buyer can execute the purchase with their own token permit.
- Dashboard cards for wallet balance, bank vault balance, and top depositors.

---

### 6. Useful `cast` helpers

```bash
# Query Bank balance for an address
cast call $BANK_ADDRESS "balances(address)(uint256)" $USER_ADDRESS --rpc-url $RPC_URL

# Fetch PermitToken nonce before signing a permit
cast call $TOKEN_ADDRESS "nonces(address)(uint256)" $USER_ADDRESS --rpc-url $RPC_URL

# Compute hashPermitBuy for off-chain signing
cast call $MARKET_ADDRESS \
  "hashPermitBuy(address,address,uint256,uint256,uint256)(bytes32)" \
  $BUYER $NFT_ADDRESS $TOKEN_ID $PRICE $DEADLINE \
  --rpc-url $RPC_URL
```

---

### 7. Repository maintenance notes

- OpenZeppelin contracts are provided via a symlinked copy under `lib/openzeppelin-contracts`; do not delete the symlink unless you adjust the remapping in `foundry.toml`.
- The tests rely on Foundry cheatcodes (`vm.sign`, `makeAddrAndKey`) to simulate off-chain signatures.
- The front end bundles `wagmi` v2 + `viem` for wallet integrations; if you need WalletConnect/AppKit features, migrate from the existing connectors.

For additional front-end details see `frontend/README.md`, which focuses on the UI-specific workflow.
