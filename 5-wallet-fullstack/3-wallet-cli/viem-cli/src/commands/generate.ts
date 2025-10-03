import { Command } from 'commander';
import { createWallet } from '../services/wallet';

export const registerGenerateCommand = (program: Command) => {
  program
    .command('generate')
    .description('Generate a new wallet and store it locally')
    .option('--force', 'Overwrite existing wallet file')
    .option('-p, --password <password>', 'Encrypt the wallet with the provided password')
    .action(async (options: { force?: boolean; password?: string }) => {
      try {
        const { account, privateKey, walletPath, encrypted } = await createWallet({
          force: Boolean(options.force),
          password: options.password,
        });
        console.log('Wallet generated successfully.');
        console.log(` Address: ${account.address}`);
        console.log(` Stored at: ${walletPath}`);
        if (encrypted) {
          console.log(' Private key encrypted with supplied password (not displayed).');
          console.log(' Remember the password; without it the wallet cannot be recovered.');
        } else {
          console.log(` Private Key: ${privateKey}`);
          console.log(' Keep the private key secure. Anyone with this key controls the funds.');
        }
      } catch (error) {
        console.error(`Failed to generate wallet: ${(error as Error).message}`);
        process.exitCode = 1;
      }
    });
};
