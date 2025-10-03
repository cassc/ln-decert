import { config as loadEnv } from 'dotenv';
import path from 'node:path';
import process from 'node:process';
import { sepolia } from 'viem/chains';

loadEnv();

const envrcPath = path.resolve(process.cwd(), '.envrc');
loadEnv({ path: envrcPath, override: false });

const rawRpcUrl = process.env.SEPOLIA_RPC_URL ?? process.env.RPC_URL;
const rawErc20TokenAddress = process.env.ERC20_TOKEN_ADDRESS;
const chainId = Number.parseInt(process.env.CHAIN_ID ?? `${sepolia.id}`, 10);
const keyStorePath = process.env.KEYSTORE_PATH
  ? path.resolve(process.env.KEYSTORE_PATH)
  : path.resolve(process.cwd(), '.wallet.json');

const requireEnv = (value: string | undefined | null, label: string): string => {
  if (!value) {
    throw new Error(`Missing required environment variable: ${label}`);
  }
  return value;
};

export const appConfig = {
  keyStorePath,
  chainId,
  chain: sepolia,
  requireRpcUrl: () => requireEnv(rawRpcUrl, 'SEPOLIA_RPC_URL or RPC_URL'),
  requireErc20TokenAddress: () => requireEnv(rawErc20TokenAddress, 'ERC20_TOKEN_ADDRESS'),
  optional: {
    rpcUrl: rawRpcUrl,
    erc20TokenAddress: rawErc20TokenAddress,
  },
};
