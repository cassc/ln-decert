import { config } from 'dotenv';
import { createPublicClient, getAddress, http, parseAbi } from 'viem';

type StopFn = () => void;

config();

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    console.error(`Missing ${key} in environment.`);
    process.exit(1);
  }
  return value;
}

const rpcUrl = requireEnv('RPC_URL');
const contractAddress = requireEnv('NFT_MARKET_ADDRESS');
const startBlockEnv = process.env.START_BLOCK;

const startBlock = startBlockEnv ? BigInt(startBlockEnv) : undefined;

const nftMarketAbi = parseAbi([
  'event Listed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price)',
  'event Purchase(address indexed buyer, address indexed seller, address indexed nft, uint256 tokenId, uint256 price)'
]);

const client = createPublicClient({
  transport: http(rpcUrl)
});

function logEvent(tag: string, payload: Record<string, unknown>) {
  const time = new Date().toISOString();
  console.log(JSON.stringify({ time, tag, ...payload }));
}

async function main() {
  const address = getAddress(contractAddress);

  const stops: StopFn[] = [];

  const listedStop = client.watchContractEvent({
    address,
    abi: nftMarketAbi,
    eventName: 'Listed',
    onLogs: (logs) => {
      logs.forEach((log) => {
        const { seller, nft, tokenId, price } = log.args;
        logEvent('LISTED', {
          seller,
          nft,
          tokenId: tokenId?.toString(),
          price: price?.toString(),
          txHash: log.transactionHash
        });
      });
    },
    onError: (err) => {
      console.error('Listed watcher error:', err);
    },
    fromBlock: startBlock
  });

  stops.push(listedStop);

  const purchaseStop = client.watchContractEvent({
    address,
    abi: nftMarketAbi,
    eventName: 'Purchase',
    onLogs: (logs) => {
      logs.forEach((log) => {
        const { buyer, seller, nft, tokenId, price } = log.args;
        logEvent('PURCHASE', {
          buyer,
          seller,
          nft,
          tokenId: tokenId?.toString(),
          price: price?.toString(),
          txHash: log.transactionHash
        });
      });
    },
    onError: (err) => {
      console.error('Purchase watcher error:', err);
    },
    fromBlock: startBlock
  });

  stops.push(purchaseStop);

  console.log('Listening for NFTMarket events...');

  const stopAll = () => {
    stops.forEach((stop) => stop());
    console.log('Stopped listeners.');
  };

  process.once('SIGINT', () => {
    stopAll();
    process.exit(0);
  });

  process.once('SIGTERM', () => {
    stopAll();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error('Listener failed to start:', err);
  process.exit(1);
});
