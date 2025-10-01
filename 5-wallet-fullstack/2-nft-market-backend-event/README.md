# NFT Market backend

This repo holds the NFT market contracts and the backend listener.

## Deploy the contracts

- Run `forge build` to make sure the contracts compile.
- Run `export RPC_URL=<https endpoint>` (or pass `--rpc-url` on each command) and optionally `export PRIVATE_KEY=<hex private key without 0x>` if you prefer env vars.
- Deploy the ERC20 token with `forge script script/DeployToken.s.sol --rpc-url $RPC_URL --broadcast` (append `--private-key <hex key>` when you do not export `PRIVATE_KEY`) and save the printed address.
- Deploy the market with `export TOKEN_ADDRESS=<token address>` then `forge script script/DeployNFTMarket.s.sol --rpc-url $RPC_URL --broadcast` (again add `--private-key <hex key>` if you rely on CLI args) and save the printed address. If you don't configure the TOKEN_ADDRESS a new token will be deployed and used as the payment token.
- (Optional) Mint demo NFTs with `export MINT_TO=<wallet>`, set `TOKEN_URI_0`, `TOKEN_URI_1`, `TOKEN_URI_2`, then run `forge script script/DeployNFTAndMint.s.sol --rpc-url $RPC_URL --broadcast`.

## Run the backend listener

- Run `npm install`.
- Copy `.env.example` to `.env`.
- Fill `RPC_URL` with your endpoint and `NFT_MARKET_ADDRESS` with the market address.
- (Optional) set `START_BLOCK` if you want to read old events.
- Start the watcher with `npm run dev` or `npm run start`.
- The script prints one JSON line per `Listed` or `Purchase` event.


## Examples

1. Mint some NFTs, e.g. [DecentMarketNFT](https://sepolia.etherscan.io/address/0x19889347BE8dc28b7C555F6CDb9B21bF1b01Ce29).
2. The NFT owner approves the [NFTMarket](https://sepolia.etherscan.io/address/0x6ace637683e010f9fb4dcccdb3c50c28294736e6#code) to spend the minted NFTs.
3. The NFT owner lists the minted NFT on NFTMarket.
4. A buyer who holds the [payment token](https://sepolia.etherscan.io/address/0x4Af5347243f5845cFe7a102e651e661eC1Ce7437#code) wants to buy the listed NFT.
   1. The buyer approves NFTMarket to spend the payment token.
   2. The buyer calls `buyNFT` to buy the NFT from the market.


```bash
❯ pnpm run dev

> 2-nft-market-backend-event@1.0.0 dev /home/garfield/projects/cassc/ln-decert/5-wallet-fullstack/2-nft-market-backend-event
> tsx watch listener/index.ts

[dotenv@17.2.3] injecting env (0) from .env -- tip: 🗂️ backup and recover secrets: https://dotenvx.com/ops
Listening for NFTMarket events...
{"time":"2025-10-01T13:56:03.694Z","tag":"LISTED","seller":"0xbfDB175c3A4AD1965d2137a18B88a63e16A38426","nft":"0x19889347BE8dc28b7C555F6CDb9B21bF1b01Ce29","tokenId":"0","price":"42","txHash":"0x3aaa1e484f82483e1a8dc23f43d64d67c32162302ee063cdde504e3a8bb47eab"}
{"time":"2025-10-01T14:03:00.015Z","tag":"PURCHASE","buyer":"0xD150b45b2c76b65231B682FDbF896A304809209F","seller":"0xbfDB175c3A4AD1965d2137a18B88a63e16A38426","nft":"0x19889347BE8dc28b7C555F6CDb9B21bF1b01Ce29","tokenId":"0","price":"42","txHash":"0x7dad0e329abd5842e955b388c02feb2d68d4b006583ba1c4e103444a70445ef1"}
```
