import NFTMarketABI from './NFTMarket.abi.json'
import DecentMarketNFTABI from './DecentMarketNFT.abi.json'
import DecentMarketTokenABI from './DecentMarketToken.abi.json'

// Contract addresses - update these with your deployed contract addresses
export const CONTRACTS = {
  NFTMarket: {
    address: (process.env.NEXT_PUBLIC_NFT_MARKET_ADDRESS || '0x0') as `0x${string}`,
    abi: NFTMarketABI,
  },
  DecentMarketNFT: {
    address: (process.env.NEXT_PUBLIC_NFT_ADDRESS || '0x0') as `0x${string}`,
    abi: DecentMarketNFTABI,
  },
  DecentMarketToken: {
    address: (process.env.NEXT_PUBLIC_TOKEN_ADDRESS || '0x0') as `0x${string}`,
    abi: DecentMarketTokenABI,
  },
} as const

export type ContractName = keyof typeof CONTRACTS
