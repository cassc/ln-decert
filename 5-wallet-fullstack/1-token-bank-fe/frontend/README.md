# Token Bank Frontend

This app lets you talk to the Bank smart contract. You can connect a wallet, check your saved ETH, deposit more, and (if you are the admin) withdraw.

## Setup

1. Copy the sample env file and edit the values:
   ```bash
   cp .env.example .env.local
   ```
   Fill in the Bank contract address, the chain id, and an RPC URL.
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

- Click **Connect Wallet** to link your browser wallet.
- The **Your deposit** card shows the value stored in the Bank contract for the connected account.
- The **Bank vault** card shows the ETH held by the Bank contract itself.
- Use the **Deposit** form to send ETH into the Bank contract.
- The **Withdraw** form only works for the admin wallet set on-chain. Non-admin wallets will see a warning and the call will fail on-chain.
- Status messages appear under each form after you sign a transaction.

## Notes

- The UI depends on `viem` and `wagmi` for wallet and contract access.
- All addresses must be checksum style strings starting with `0x`.
- Update the env file when you deploy the contract to a new chain.
