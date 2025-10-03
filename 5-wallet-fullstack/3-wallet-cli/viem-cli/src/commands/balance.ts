import { Command } from 'commander';
import { formatEther, formatUnits, erc20Abi } from 'viem';
import { appConfig } from '../config';
import { loadStoredAccount } from '../services/wallet';
import { getPublicClient } from '../services/viemClients';
import { getTokenMetadata } from '../services/token';

export const registerBalanceCommand = (program: Command) => {
  program
    .command('balance')
    .description('Show the wallet balance for the configured ERC20 token and native ETH')
    .action(async () => {
      try {
        const account = await loadStoredAccount();
        const client = getPublicClient();
        const tokenAddress = appConfig.requireErc20TokenAddress() as `0x${string}`;

        const [nativeBalance, tokenBalance] = await Promise.all([
          client.getBalance({ address: account.address }),
          client.readContract({
            address: tokenAddress,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [account.address],
          }),
        ]);

        const { decimals, symbol } = await getTokenMetadata(client, tokenAddress);

        console.log(`Wallet address: ${account.address}`);
        console.log(`Native ETH balance: ${formatEther(nativeBalance)} ETH`);
        console.log(
          `Token balance: ${formatUnits(tokenBalance as bigint, decimals)} ${symbol}`
        );
      } catch (error) {
        console.error(`Failed to fetch balances: ${(error as Error).message}`);
        process.exitCode = 1;
      }
    });
};
