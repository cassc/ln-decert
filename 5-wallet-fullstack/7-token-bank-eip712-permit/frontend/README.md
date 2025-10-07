# Permit Token Bank dApp

## Setup

1. Copy the sample env file and edit the values:
   ```bash
   cp .env.example .env.local
   ```
   Required variables:
   - `VITE_BANK_ADDRESS`
   - `VITE_TOKEN_ADDRESS`
   - `VITE_NFT_ADDRESS`
   - `VITE_MARKET_ADDRESS`
   - `VITE_WHITELIST_SIGNER` (optional in case you rotate the signer later)
   - Chain metadata (`VITE_CHAIN_ID`, `VITE_CHAIN_NAME`, `VITE_RPC_URL`)
2. Install packages:
   ```bash
   npm install
   ```
3. Start the dev server:
   ```bash
   npm run dev
   ```
   The app opens on `http://localhost:5173`.

## Usage

- **Connect wallet** using an injected connector (MetaMask, Rabby, etc.).
- **Permit deposit** signs an ERC20 permit for `PermitToken` and submits `Bank.permitDeposit`.
- **Withdraw** redeems your entire Bank balance in `PermitToken`.
- **Marketplace setup** lets you grant token allowance, approve NFTs, and (if you are the collection owner) mint new tokens.
- **List NFT** posts a listing on `NFTMarket` with a price in `PermitToken`.
- **Permit buy** accepts the whitelist signature issued by the project team and finalises the purchase.
- The table at the bottom mirrors on-chain state: owners, URIs, listing price/seller, plus top bank depositors.

## Notes

- Uses `wagmi` v2 + `viem`; configure additional connectors in `src/lib/wagmi.ts` if required.
- The helper that splits signatures expects a 65-byte hex string (Metamask’s `0x...1b` format).
- Chain metadata in `.env.local` should match the deployment environment to avoid signing-domain mismatches.
- See the root `README.md` for deployment instructions, Foundry tests, and whitelist guidance.
