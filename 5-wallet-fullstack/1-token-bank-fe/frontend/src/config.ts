const DEFAULT_CHAIN_ID = 11_155_111;
const DEFAULT_CHAIN_NAME = 'Sepolia Testnet';
const DEFAULT_RPC_URL = 'https://1rpc.io/sepolia';

const rawChainId = Number.parseInt(import.meta.env.VITE_CHAIN_ID ?? '', 10);
export const chainId = Number.isNaN(rawChainId) ? DEFAULT_CHAIN_ID : rawChainId;
export const chainName = import.meta.env.VITE_CHAIN_NAME ?? DEFAULT_CHAIN_NAME;
export const rpcUrl = import.meta.env.VITE_RPC_URL ?? DEFAULT_RPC_URL;
const maybeBankAddress = import.meta.env.VITE_BANK_ADDRESS ?? '';
const bankPattern = /^0x[a-fA-F0-9]{40}$/;
export const bankAddress = bankPattern.test(maybeBankAddress)
  ? (maybeBankAddress as `0x${string}`)
  : '';

export const isBankConfigured = bankAddress.length > 0;
