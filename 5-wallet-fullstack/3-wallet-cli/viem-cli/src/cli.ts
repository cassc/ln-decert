#!/usr/bin/env node
import { Command } from 'commander';
import pkg from '../package.json';
import { registerGenerateCommand } from './commands/generate';
import { registerBalanceCommand } from './commands/balance';
import { registerPrepareTransferCommand } from './commands/prepareTransfer';
import { registerSignCommand } from './commands/sign';
import { registerSendCommand } from './commands/send';

const program = new Command();

program
  .name('viem-wallet')
  .description('CLI wallet powered by Viem for Sepolia ERC20 transfers')
  .version(pkg.version ?? '0.0.0');

registerGenerateCommand(program);
registerBalanceCommand(program);
registerPrepareTransferCommand(program);
registerSignCommand(program);
registerSendCommand(program);

program.parseAsync().catch((error: unknown) => {
  console.error(`Unexpected error: ${(error as Error).message}`);
  process.exitCode = 1;
});
