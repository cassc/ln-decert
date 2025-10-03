import { Command } from 'commander';
import { createWallet } from '../services/wallet';

export const registerGenerateCommand = (program: Command) => {
  program
    .command('generate')
    .description('Generate a new wallet and store it locally')
    .option('--force', 'Overwrite existing wallet file')
    .action(async (options: { force?: boolean }) => {
      try {
        const { account, privateKey, walletPath } = await createWallet({ force: Boolean(options.force) });
        console.log('Wallet generated successfully.');
        console.log(` Address: ${account.address}`);
        console.log(` Private Key: ${privateKey}`);
        console.log(` Stored at: ${walletPath}`);
        console.log('Keep the private key secure. Anyone with this key controls the funds.');
      } catch (error) {
        console.error(`Failed to generate wallet: ${(error as Error).message}`);
        process.exitCode = 1;
      }
    });
};
