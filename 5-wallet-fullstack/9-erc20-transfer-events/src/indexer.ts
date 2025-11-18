import {
  Address,
  BlockNumber,
  createPublicClient,
  http,
  parseAbiItem,
} from "viem";
import { config } from "./config";
import { TransferRow, createTransferStore } from "./db";

const transferEvent = parseAbiItem(
  "event Transfer(address indexed from, address indexed to, uint256 value)"
);

type IndexerOptions = {
  tokenAddress: Address;
  startBlock: bigint;
  pollIntervalMs: number;
  blockBatchSize: number;
};

const client = createPublicClient({
  transport: http(config.rpcUrl),
});

const store = createTransferStore(config.dbPath);

async function fetchTransfers(
  tokenAddress: Address,
  fromBlock: BlockNumber,
  toBlock: BlockNumber
): Promise<TransferRow[]> {
  if (toBlock < fromBlock) return [];

  const logs = await client.getLogs({
    address: tokenAddress,
    event: transferEvent,
    fromBlock,
    toBlock,
  });

  if (!logs.length) return [];

  const uniqueBlocks = Array.from(
    new Set(logs.map((log) => log.blockNumber))
  ).sort((a, b) => (a < b ? -1 : 1));

  const blockTimeMap = new Map<bigint, bigint>();
  for (const blockNumber of uniqueBlocks) {
    const block = await client.getBlock({ blockNumber });
    blockTimeMap.set(blockNumber, block.timestamp);
  }

  return logs
    .map((log) => {
      if (!log.transactionHash || !log.args) return undefined;
      const ts = blockTimeMap.get(log.blockNumber) ?? 0n;
      return {
        txHash: log.transactionHash,
        logIndex: Number(log.logIndex),
        blockNumber: Number(log.blockNumber),
        blockTime: Number(ts),
        from: (log.args.from as string).toLowerCase(),
        to: (log.args.to as string).toLowerCase(),
        value: (log.args.value as bigint).toString(),
      } satisfies TransferRow;
    })
    .filter(Boolean) as TransferRow[];
}

function nextFromBlock(startBlock: bigint): bigint {
  const highest = store.getHighestBlock();
  if (highest === null) return startBlock;
  const next = BigInt(highest) + 1n;
  return next > startBlock ? next : startBlock;
}

export function startIndexer(options: IndexerOptions) {
  let syncing = false;

  const syncOnce = async () => {
    if (syncing) return;
    syncing = true;
    try {
      let fromBlock = nextFromBlock(options.startBlock);
      const latestBlock = await client.getBlockNumber();

      while (fromBlock <= latestBlock) {
        const toBlockCandidate = fromBlock + BigInt(options.blockBatchSize) - 1n;
        const toBlock =
          toBlockCandidate > latestBlock ? latestBlock : toBlockCandidate;

        const transfers = await fetchTransfers(
          options.tokenAddress,
          fromBlock as BlockNumber,
          toBlock as BlockNumber
        );

        store.addTransfers(transfers);
        fromBlock = toBlock + 1n;
      }
    } catch (error) {
      console.error("Sync error:", error);
    } finally {
      syncing = false;
      setTimeout(syncOnce, options.pollIntervalMs);
    }
  };

  syncOnce();
}

export { store };
