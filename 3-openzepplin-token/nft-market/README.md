# Decent Market NFT

> 用 ERC721 标准（可复用 OpenZepplin 库）发行一个自己 NFT 合约，并用图片铸造几个 NFT ， 请把图片和 Meta Json数据上传到去中心的存储服务中，请贴出在 OpenSea 的 NFT 链接。

> 编写一个简单的 NFTMarket 合约，使用自己发行的ERC20 扩展 Token 来买卖 NFT， NFTMarket 的函数有：

> list() : 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。

> buyNFT() : 普通的购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

> 实现ERC20 扩展 Token 所要求的接收者方法 tokensReceived  ，在 tokensReceived 中实现NFT 购买功能(注意扩展的转账需要添加一个额外数据参数)。

This Foundry project implements a complete NFT marketplace ecosystem with ERC721 NFTs, ERC20 tokens, and a marketplace contract using OpenZeppelin.

## Contracts

- `src/DecentMarketNFT.sol` - An Ownable ERC721 contract with stored token URIs for the NFT collection.
- `src/DecentMarketToken.sol` - An ERC20 token contract (DMT) that serves as the payment token for the marketplace.
- `src/NFTMarket.sol` - A marketplace contract that allows listing and trading NFTs using DecentMarketToken as payment.

Before you list an NFT, call `setApprovalForAll(address(market), true)` on your NFT contract. This approval lets the market move the token when someone buys it.

## Deployment Scripts

The project includes three deployment scripts for different components:

### 1. Deploy DecentMarketToken (ERC20)

```bash
forge script script/DeployToken.s.sol:DeployToken --rpc-url https://1rpc.io/sepolia --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. Deploy NFTMarket

```bash
# Option 1: Deploy with a new token
forge script script/DeployNFTMarket.s.sol:DeployNFTMarket --rpc-url https://1rpc.io/sepolia --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Option 2: Deploy with existing token (set TOKEN_ADDRESS environment variable)
export TOKEN_ADDRESS=0xYourTokenAddress
forge script script/DeployNFTMarket.s.sol:DeployNFTMarket --rpc-url https://1rpc.io/sepolia --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 3. Deploy NFT and Mint

1. Upload your PNG files to IPFS and note the `ipfs://` links.
2. Create JSON metadata files that point to those images and upload them to IPFS too.
3. Set environment variables before the script run:
   - `PRIVATE_KEY` for the deployer wallet.
   - `MINT_TO` for the wallet that receives the tokens.
   - `TOKEN_URI_0`, `TOKEN_URI_1`, `TOKEN_URI_2` for the metadata URIs.
   - `ETHERSCAN_API_KEY` for automatic contract verification.
4. Run `forge script script/DeployNFTAndMint.s.sol:DeployNFTAndMint --rpc-url https://1rpc.io/sepolia --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY`.

## Contract Verification

To verify after deployment, run:
```bash
forge verify-contract <DEPLOYED_CONTRACT_ADDRESS> <CONTRACT_PATH>:<CONTRACT_NAME> --chain-id <CHAIN_ID> --etherscan-api-key $ETHERSCAN_API_KEY
```

Replace `<DEPLOYED_CONTRACT_ADDRESS>`, `<CONTRACT_PATH>`, `<CONTRACT_NAME>`, and `<CHAIN_ID>` with your actual values.

Examples for Sepolia deployment:

```bash
# Verify DecentMarketNFT
forge verify-contract 0xYourNFTAddress src/DecentMarketNFT.sol:DecentMarketNFT --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY

# Verify DecentMarketToken
forge verify-contract 0xYourTokenAddress src/DecentMarketToken.sol:DecentMarketToken --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY

# Verify NFTMarket (requires constructor args)
forge verify-contract 0xYourMarketAddress src/NFTMarket.sol:NFTMarket --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" 0xYourTokenAddress)
```



## View on OpenSea

After Polygon deployment (OpenSea no longer supports testnet deployment):

1. Wait 5-10 minutes for OpenSea to index your contract
2. Visit: `https://opensea.io/assets/matic/[YOUR_CONTRACT_ADDRESS]/[TOKEN_ID]`
3. Or run `forge script script/GetOpenSeaUrls.s.sol:GetOpenSeaUrls` to get all URLs

## Tests

Run `forge test` to prove owner-only minting.
