import { Command } from 'commander';
import { promises as fs } from 'node:fs';
import { keccak256 } from 'viem';
import { loadStoredAccount } from '../services/wallet';
import { getWalletClient } from '../services/viemClients';
import { stringifyWithBigInt } from '../utils/serialization';

type PreparedTransferPayload = {
  request: Record<string, unknown> & { to: `0x${string}`; data: `0x${string}` };
};

const readPayload = async (file?: string, json?: string): Promise<PreparedTransferPayload> => {
  if (!file && !json) {
    throw new Error('Provide either --file or --json with the prepared transaction payload.');
  }

  const raw = file ? await fs.readFile(file, 'utf8') : json ?? '';
  try {
    return JSON.parse(raw) as PreparedTransferPayload;
  } catch (error) {
    throw new Error(`Failed to parse prepared transaction: ${(error as Error).message}`);
  }
};

export const registerSignCommand = (program: Command) => {
  program
    .command('sign')
    .description('Sign a prepared ERC20 transfer transaction with the stored wallet')
    .option('-f, --file <file>', 'Path to the prepared transaction JSON')
    .option('-j, --json <payload>', 'Prepared transaction JSON string (escaped)')
    .option('-o, --output <file>', 'Write the signed transaction JSON to a file', 'signed.json')
    .option('-p, --password <password>', 'Password to decrypt the stored wallet')
    .action(async (options: { file?: string; json?: string; output?: string; password?: string }) => {
      try {
        const payload = await readPayload(options.file, options.json);
        if (!payload.request) {
          throw new Error('Prepared payload missing `request` field.');
        }

        const account = await loadStoredAccount({ password: options.password });
        const walletClient = getWalletClient(account);

        const request = { ...payload.request, account } as Parameters<
          typeof walletClient.signTransaction
        >[0];

        const signedTransaction = await walletClient.signTransaction(request);
        const txHash = keccak256(signedTransaction);

        const result = {
          signedTransaction,
          txHash,
        };

        const serialized = stringifyWithBigInt(result, 2);

        if (options.output) {
          await fs.writeFile(options.output, serialized, 'utf8');
          console.log(`Signed transaction saved to ${options.output}`);
        } else {
          console.log(serialized);
        }
      } catch (error) {
        console.error(`Failed to sign transaction: ${(error as Error).message}`);
        process.exitCode = 1;
      }
    });
};
