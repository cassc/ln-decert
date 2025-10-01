# NFT Market backend

This repo holds the NFT market contracts and the backend listener.

## Deploy the contracts

- Run `forge build` to make sure the contracts compile.
- Run `export RPC_URL=<https endpoint>` (or pass `--rpc-url` on each command) and optionally `export PRIVATE_KEY=<hex private key without 0x>` if you prefer env vars.
- Deploy the ERC20 token with `forge script script/DeployToken.s.sol --rpc-url $RPC_URL --broadcast` (append `--private-key <hex key>` when you do not export `PRIVATE_KEY`) and save the printed address.
- Deploy the market with `export TOKEN_ADDRESS=<token address>` then `forge script script/DeployNFTMarket.s.sol --rpc-url $RPC_URL --broadcast` (again add `--private-key <hex key>` if you rely on CLI args) and save the printed address.
- (Optional) Mint demo NFTs with `export MINT_TO=<wallet>`, set `TOKEN_URI_0`, `TOKEN_URI_1`, `TOKEN_URI_2`, then run `forge script script/DeployNFTAndMint.s.sol --rpc-url $RPC_URL --broadcast`.

## Run the backend listener

- Run `npm install`.
- Copy `.env.example` to `.env`.
- Fill `RPC_URL` with your endpoint and `NFT_MARKET_ADDRESS` with the market address.
- (Optional) set `START_BLOCK` if you want to read old events.
- Start the watcher with `npm run dev` or `npm run start`.
- The script prints one JSON line per `Listed` or `Purchase` event.
