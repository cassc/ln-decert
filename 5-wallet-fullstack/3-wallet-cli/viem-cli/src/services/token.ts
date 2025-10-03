import { erc20Abi } from 'viem';
import type { PublicClient } from 'viem';

export type TokenMetadata = {
  decimals: number;
  symbol: string;
};

export const getTokenMetadata = async (
  client: PublicClient,
  tokenAddress: `0x${string}`
): Promise<TokenMetadata> => {
  let decimals = 18;
  let symbol = 'TOKEN';

  try {
    decimals = Number(
      await client.readContract({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'decimals',
      })
    );
  } catch (error) {
    console.warn('Warning: failed to read token decimals, defaulting to 18.', (error as Error).message);
  }

  try {
    symbol = (await client.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'symbol',
    })) as string;
  } catch (error) {
    console.warn('Warning: failed to read token symbol.', (error as Error).message);
  }

  return { decimals, symbol };
};
