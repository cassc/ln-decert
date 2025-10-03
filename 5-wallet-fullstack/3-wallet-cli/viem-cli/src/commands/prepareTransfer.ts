import { Command } from 'commander';
import { promises as fs } from 'node:fs';
import { erc20Abi, parseUnits, encodeFunctionData } from 'viem';
import { appConfig } from '../config';
import { loadStoredAccount } from '../services/wallet';
import { getPublicClient } from '../services/viemClients';
import { getTokenMetadata } from '../services/token';
import { stringifyWithBigInt } from '../utils/serialization';

const assertHexAddress = (value: string, label: string): `0x${string}` => {
  if (!value || !value.startsWith('0x')) {
    throw new Error(`Invalid ${label}. Expected hex address starting with 0x.`);
  }
  return value as `0x${string}`;
};

export const registerPrepareTransferCommand = (program: Command) => {
  program
    .command('prepare-transfer')
    .description('Prepare an unsigned EIP-1559 ERC20 transfer transaction')
    .requiredOption('-t, --to <address>', 'Recipient address')
    .requiredOption('-a, --amount <amount>', 'Token amount to send (human readable)')
    .option('-d, --decimals <decimals>', 'Token decimals override')
    .option('-o, --output <file>', 'Write the prepared transaction JSON to a file')
    .option('-p, --password <password>', 'Password to decrypt the stored wallet')
    .action(async (options: {
      to: string;
      amount: string;
      decimals?: string;
      output?: string;
      password?: string;
    }) => {
      try {
        const account = await loadStoredAccount({ password: options.password });
        const client = getPublicClient();
        const tokenAddress = appConfig.requireErc20TokenAddress() as `0x${string}`;
        const { decimals } = await getTokenMetadata(client, tokenAddress);
        const effectiveDecimals = options.decimals
          ? Number.parseInt(options.decimals, 10)
          : decimals;

        if (!Number.isInteger(effectiveDecimals) || effectiveDecimals < 0) {
          throw new Error('Decimals must be a non-negative integer.');
        }

        const value = parseUnits(options.amount, effectiveDecimals);
        const to = assertHexAddress(options.to, 'recipient address');

        // Encode the contract function call data
        const data = encodeFunctionData({
          abi: erc20Abi,
          functionName: 'transfer',
          args: [to, value],
        });

        // Simulate the contract call to validate
        await client.simulateContract({
          address: tokenAddress,
          abi: erc20Abi,
          functionName: 'transfer',
          args: [to, value],
          account,
        });

        // Prepare the complete transaction request with EIP-1559 parameters
        const request = await client.prepareTransactionRequest({
          account,
          to: tokenAddress,
          data,
          type: 'eip1559',
        });

        const payload = {
          chainId: appConfig.chainId,
          tokenAddress,
          from: account.address,
          to,
          amount: options.amount,
          decimals: effectiveDecimals,
          request,
        };

        const serialized = stringifyWithBigInt(payload, 2);

        if (options.output) {
          await fs.writeFile(options.output, serialized, 'utf8');
          console.log(`Prepared transaction saved to ${options.output}`);
        } else {
          console.log(serialized);
        }
      } catch (error) {
        console.error(`Failed to prepare transfer: ${(error as Error).message}`);
        process.exitCode = 1;
      }
    });
};
