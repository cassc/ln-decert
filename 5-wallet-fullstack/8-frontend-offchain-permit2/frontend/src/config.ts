import type { Address } from 'viem';

const DEFAULT_CHAIN_ID = 11_155_111;
const DEFAULT_CHAIN_NAME = 'Sepolia Testnet';
const DEFAULT_RPC_URL = 'https://1rpc.io/sepolia';
const DEFAULT_PERMIT2 = '0x000000000022D473030F116dDEE9F6B43AC78BA3';
const ADDRESS_PATTERN = /^0x[a-fA-F0-9]{40}$/;

const rawChainId = Number.parseInt(import.meta.env.VITE_CHAIN_ID ?? '', 10);
export const chainId = Number.isNaN(rawChainId) ? DEFAULT_CHAIN_ID : rawChainId;
export const chainName = import.meta.env.VITE_CHAIN_NAME ?? DEFAULT_CHAIN_NAME;
export const rpcUrl = import.meta.env.VITE_RPC_URL ?? DEFAULT_RPC_URL;

const normalizeAddress = (value?: string): Address | undefined => {
  if (!value) {
    return undefined;
  }
  return ADDRESS_PATTERN.test(value) ? (value as Address) : undefined;
};

export const bankAddress = normalizeAddress(import.meta.env.VITE_BANK_ADDRESS);
export const tokenAddress = normalizeAddress(import.meta.env.VITE_TOKEN_ADDRESS);
export const permit2Address = normalizeAddress(import.meta.env.VITE_PERMIT2_ADDRESS) ?? (DEFAULT_PERMIT2 as Address);

export const isAppConfigured = Boolean(bankAddress && tokenAddress);
