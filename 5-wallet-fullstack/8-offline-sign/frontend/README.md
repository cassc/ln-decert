# Token Bank Frontend

This app lets you talk to the Bank smart contract. You can connect a wallet, check your saved ETH, deposit more through Permit2, and withdraw.

## Setup

1. Copy the sample env file and edit the values:
   ```bash
   cp .env.example .env.local
   ```
   Fill in the Bank contract address, the WETH token address, the chain id, and an RPC URL.
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
- Use **Approve Permit2 on WETH** once per wallet to grant Permit2 the allowance it needs.
- Use the **Deposit** form to create a Permit2 signature and send the `depositWithPermit2` transaction. The Bank pulls your WETH, unwraps it to ETH, and credits the balance.
- The **Withdraw** button returns your full balance as ETH.
- Status messages appear under each form after you sign a transaction.

## Notes

- The UI depends on `viem` and `wagmi` for wallet and contract access.
- All addresses must be checksum style strings starting with `0x`.
- Update the env file when you deploy the contract to a new chain.
- Each depositor must hold WETH and, before the first deposit, approve Permit2 to spend it. The UI exposes an approval button that sends an infinite allowance; revoke it manually if you prefer smaller limits.
