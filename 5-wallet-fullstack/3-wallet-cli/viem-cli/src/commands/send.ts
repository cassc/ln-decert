import { Command } from 'commander';
import { promises as fs } from 'node:fs';
import { getPublicClient } from '../services/viemClients';

type SignedPayload = {
  signedTransaction: `0x${string}`;
  txHash?: `0x${string}`;
};

const assertHex = (value: string, label: string): `0x${string}` => {
  if (!value.startsWith('0x')) {
    throw new Error(`${label} must be a hex string starting with 0x.`);
  }
  return value as `0x${string}`;
};

const readSignedPayload = async (file?: string, json?: string): Promise<SignedPayload> => {
  if (!file && !json) {
    throw new Error('Provide either --file or --json with the signed transaction.');
  }

  const raw = file ? await fs.readFile(file, 'utf8') : json ?? '';
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed === 'string') {
      return { signedTransaction: assertHex(parsed, 'Signed transaction') };
    }
    if (typeof parsed?.signedTransaction === 'string') {
      return {
        signedTransaction: assertHex(parsed.signedTransaction, 'Signed transaction'),
        txHash: parsed.txHash ? assertHex(parsed.txHash, 'Transaction hash') : undefined,
      };
    }
    throw new Error('JSON payload missing `signedTransaction` field.');
  } catch (error) {
    if (json) {
      return { signedTransaction: assertHex(json, 'Signed transaction') };
    }
    throw new Error(`Failed to parse signed transaction: ${(error as Error).message}`);
  }
};

export const registerSendCommand = (program: Command) => {
  program
    .command('send')
    .description('Broadcast a signed transaction to the Sepolia network')
    .option('-f, --file <file>', 'Path to the signed transaction JSON or raw hex string')
    .option('-j, --json <payload>', 'Signed transaction JSON string or raw hex string')
    .option('-w, --wait', 'Wait for the transaction receipt')
    .action(async (options: { file?: string; json?: string; wait?: boolean }) => {
      try {
        const { signedTransaction } = await readSignedPayload(options.file, options.json);

        const client = getPublicClient();
        const hash = await client.sendRawTransaction({ serializedTransaction: signedTransaction });
        console.log(`Transaction broadcasted. Hash: ${hash}`);
        console.log(`Explorer: https://sepolia.etherscan.io/tx/${hash}`);

        if (options.wait) {
          console.log('Waiting for 1 confirmation...');
          const receipt = await client.waitForTransactionReceipt({ hash });
          console.log(`Status: ${receipt.status}`);
          console.log(`Block number: ${receipt.blockNumber}`);
        }
      } catch (error) {
        console.error(`Failed to send transaction: ${(error as Error).message}`);
        process.exitCode = 1;
      }
    });
};
