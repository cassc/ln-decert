# Decent Market NFT

> 用 ERC721 标准（可复用 OpenZepplin 库）发行一个自己 NFT 合约，并用图片铸造几个 NFT ， 请把图片和 Meta Json数据上传到去中心的存储服务中，请贴出在 OpenSea 的 NFT 链接。




This Foundry project mints a small ERC721 collection using OpenZeppelin.

## Contracts

- `src/DecentMarketNFT.sol` keeps an Ownable ERC721 with stored token URIs.

## Deploy and mint

### Option 1: Polygon (Recommended - OpenSea support + cheap!)

1. Get free MATIC from [Polygon Faucet](https://faucet.polygon.technology/) 
2. Set up environment variables (see `.env.example`)
3. Deploy: `forge script script/DeployPolygon.s.sol:DeployPolygon --rpc-url https://polygon-rpc.com --broadcast`
4. Your NFTs will appear on OpenSea automatically!

### Option 2: Sepolia Testnet

1. Upload your PNG files to IPFS and note the `ipfs://` links.
2. Create JSON metadata files that point to those images and upload them to IPFS too.
3. Set environment variables before the script run:
   - `PRIVATE_KEY` for the deployer wallet.
   - `MINT_TO` for the wallet that receives the tokens.
   - `TOKEN_URI_0`, `TOKEN_URI_1`, `TOKEN_URI_2` for the IPFS metadata links.
4. Run `forge script script/DeployAndMint.s.sol:DeployAndMint --rpc-url https://1rpc.io/sepolia --broadcast`.

## View on OpenSea

After Polygon deployment:

1. Wait 5-10 minutes for OpenSea to index your contract
2. Visit: `https://opensea.io/assets/matic/[YOUR_CONTRACT_ADDRESS]/[TOKEN_ID]`
3. Or run `forge script script/GetOpenSeaUrls.s.sol:GetOpenSeaUrls` to get all URLs

## Tests

Run `forge test` to prove owner-only minting.
