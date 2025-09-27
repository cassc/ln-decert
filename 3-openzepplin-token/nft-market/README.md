# Decent Market NFT

This Foundry project mints a small ERC721 collection using OpenZeppelin.

## Contracts

- `src/DecentMarketNFT.sol` keeps an Ownable ERC721 with stored token URIs.

## Deploy and mint

1. Upload your PNG files to IPFS and note the `ipfs://` links.
2. Create JSON metadata files that point to those images and upload them too.
3. Set environment variables before the script run:
   - `PRIVATE_KEY` for the deployer wallet.
   - `MINT_TO` for the wallet that receives the tokens.
   - `TOKEN_URI_0`, `TOKEN_URI_1`, `TOKEN_URI_2` for the metadata links.
4. Run `forge script script/DeployAndMint.s.sol:DeployAndMint --rpc-url <RPC_URL> --broadcast`.

## Tests

Run `forge test` to prove owner-only minting.
