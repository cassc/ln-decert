import { existsSync } from 'node:fs';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
import type { Account } from 'viem';
import { appConfig } from '../config';
import { walletStore } from './walletStore';

export const createWallet = async ({ force = false }: { force?: boolean } = {}) => {
  const walletPath = appConfig.keyStorePath;
  if (!force && existsSync(walletPath)) {
    throw new Error(`Wallet file already exists at ${walletPath}. Use --force to overwrite.`);
  }

  const privateKey = generatePrivateKey();
  const account = privateKeyToAccount(privateKey);

  await walletStore.write(walletPath, {
    privateKey,
    address: account.address,
    createdAt: new Date().toISOString(),
  });

  return { account, privateKey, walletPath };
};

export const loadStoredAccount = async (): Promise<Account> => {
  const walletPath = appConfig.keyStorePath;
  const stored = await walletStore.read(walletPath);
  if (!stored) {
    throw new Error(`Wallet file not found at ${walletPath}. Run the generate command first.`);
  }
  return privateKeyToAccount(stored.privateKey);
};
