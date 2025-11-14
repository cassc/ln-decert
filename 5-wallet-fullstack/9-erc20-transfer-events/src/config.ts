import dotenv from "dotenv";

dotenv.config();

const parseIntEnv = (value: string | undefined, fallback: number): number =>
  value ? Number(value) : fallback;

const parseBigIntEnv = (
  value: string | undefined,
  fallback: bigint
): bigint => {
  if (!value) return fallback;
  const parsed = BigInt(value);
  return parsed >= 0 ? parsed : fallback;
};

if (!process.env.RPC_URL) {
  throw new Error("RPC_URL is required");
}

if (!process.env.TOKEN_ADDRESS) {
  throw new Error("TOKEN_ADDRESS is required");
}

export const config = {
  rpcUrl: process.env.RPC_URL,
  tokenAddress: process.env.TOKEN_ADDRESS,
  startBlock: parseBigIntEnv(process.env.START_BLOCK, 0n),
  pollIntervalMs: parseIntEnv(process.env.POLL_INTERVAL_MS, 15_000),
  blockBatchSize: parseIntEnv(process.env.BLOCK_BATCH_SIZE, 2_000),
  dbPath: process.env.DB_PATH ?? "./data/erc20-indexer.db",
};
