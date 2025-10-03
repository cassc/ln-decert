import { http, createPublicClient, createWalletClient } from 'viem';
import type { Account } from 'viem';
import { appConfig } from '../config';

export const getPublicClient = () =>
  createPublicClient({
    chain: appConfig.chain,
    transport: http(appConfig.requireRpcUrl()),
  });

export const getWalletClient = (account: Account) =>
  createWalletClient({
    account,
    chain: appConfig.chain,
    transport: http(appConfig.requireRpcUrl()),
  });
