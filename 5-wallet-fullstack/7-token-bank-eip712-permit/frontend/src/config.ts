import type { Address } from 'viem';

const DEFAULT_CHAIN_ID = 11_155_111;
const DEFAULT_CHAIN_NAME = 'Sepolia Testnet';
const DEFAULT_RPC_URL = 'https://1rpc.io/sepolia';

const rawChainId = Number.parseInt(import.meta.env.VITE_CHAIN_ID ?? '', 10);
export const chainId = Number.isNaN(rawChainId) ? DEFAULT_CHAIN_ID : rawChainId;
export const chainName = import.meta.env.VITE_CHAIN_NAME ?? DEFAULT_CHAIN_NAME;
export const rpcUrl = import.meta.env.VITE_RPC_URL ?? DEFAULT_RPC_URL;

const addressPattern = /^0x[a-fA-F0-9]{40}$/;

const maybeBankAddress = import.meta.env.VITE_BANK_ADDRESS ?? '';
export const bankAddress: Address | undefined = addressPattern.test(maybeBankAddress)
  ? (maybeBankAddress as Address)
  : undefined;

const maybeTokenAddress = import.meta.env.VITE_TOKEN_ADDRESS ?? '';
export const tokenAddress: Address | undefined = addressPattern.test(maybeTokenAddress)
  ? (maybeTokenAddress as Address)
  : undefined;

const maybeNFTAddress = import.meta.env.VITE_NFT_ADDRESS ?? '';
export const nftAddress: Address | undefined = addressPattern.test(maybeNFTAddress)
  ? (maybeNFTAddress as Address)
  : undefined;

const maybeMarketAddress = import.meta.env.VITE_MARKET_ADDRESS ?? '';
export const marketAddress: Address | undefined = addressPattern.test(maybeMarketAddress)
  ? (maybeMarketAddress as Address)
  : undefined;

const maybeWhitelistSigner = import.meta.env.VITE_WHITELIST_SIGNER ?? '';
export const whitelistSignerAddress: Address | undefined = addressPattern.test(maybeWhitelistSigner)
  ? (maybeWhitelistSigner as Address)
  : undefined;

export const isAppConfigured = Boolean(bankAddress && tokenAddress && nftAddress && marketAddress);

/**
 * Get the block explorer URL for a given chain ID
 */
export function getBlockExplorerUrl(id: number): string {
  const explorers: Record<number, string> = {
    1: 'https://etherscan.io',
    11155111: 'https://sepolia.etherscan.io',
    5: 'https://goerli.etherscan.io',
    137: 'https://polygonscan.com',
    80001: 'https://mumbai.polygonscan.com',
    42161: 'https://arbiscan.io',
    421613: 'https://goerli.arbiscan.io',
    10: 'https://optimistic.etherscan.io',
    420: 'https://goerli-optimism.etherscan.io',
    56: 'https://bscscan.com',
    97: 'https://testnet.bscscan.com',
  };
  return explorers[id] || 'https://etherscan.io';
}

/**
 * Get the block explorer URL for the configured chain
 */
export const blockExplorerUrl = getBlockExplorerUrl(chainId);

/**
 * Get the full URL to view an address on the block explorer
 */
export function getAddressUrl(address: Address, id: number = chainId): string {
  return `${getBlockExplorerUrl(id)}/address/${address}`;
}
