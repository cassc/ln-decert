/**
 * This script signs enable + presale calls, simulates them, and sends one Flashbots bundle.
 */
import { config } from "dotenv";
import {
  JsonRpcProvider,
  Wallet,
  Interface,
  TransactionRequest,
  parseUnits,
  keccak256,
  TransactionReceipt
} from "ethers";
import {
  FlashbotsBundleProvider,
  RelayResponseError,
  GetBundleStatsResponseV2
} from "@flashbots/ethers-provider-bundle";

config();

const FLASHBOTS_RELAY_URL =
  process.env.FLASHBOTS_RELAY_URL?.trim() ?? "https://relay-sepolia.flashbots.net";
const FLASHBOTS_STATUS_URL =
  process.env.FLASHBOTS_STATUS_URL?.trim() ?? "https://protect-sepolia.flashbots.net/tx/";
const RETRY_DELAY_MS = 12_000;

/**
 * Read an env var or throw if missing.
 */
function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing env var ${name}`);
  }
  return value.trim();
}

/**
 * Read an env var and coerce to bigint with fallback.
 */
function toBigIntEnv(name: string, fallback: string): bigint {
  const raw = (process.env[name] ?? fallback).trim();
  return BigInt(raw);
}

/**
 * Narrow a relay response to the error shape.
 */
function isRelayError<T extends { error: { message: string } }>(
  payload: unknown
): payload is RelayResponseError {
  return typeof payload === "object" && payload !== null && "error" in payload;
}

function formatBlockTag(blockNumber: number): string {
  return `0x${blockNumber.toString(16)}`;
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

type FlashbotsRpcResult<T> =
  | { jsonrpc: string; id: number; result: T }
  | { jsonrpc: string; id: number; error: { code?: number; message: string } };

interface BundleRpcResult {
  bundleHash: string;
}

async function flashbotsRpc<T>(payload: Record<string, unknown>, signer: Wallet): Promise<T> {
  const body = JSON.stringify(payload);
  const method = String(payload.method ?? "unknown_method");
  console.log(`[flashbotsRpc] Preparing request for ${method}`);
  const bodyHash = keccak256(Buffer.from(body));
  console.log(`[flashbotsRpc] bodyHash=${bodyHash}`);
  let signature: string;
  try {
    signature = await signer.signMessage(bodyHash);
  } catch (error) {
    console.error(`[flashbotsRpc] signer.signMessage failed for method=${method}`);
    throw error;
  }
  const headers = {
    "Content-Type": "application/json",
    "X-Flashbots-Signature": `${await signer.getAddress()}:${signature}`
  };

  console.log(`[flashbotsRpc] Sending payload: ${body}`);
  const response = await fetch(FLASHBOTS_RELAY_URL, {
    method: "POST",
    headers,
    body
  });

  if (!response.ok) {
    throw new Error(`Flashbots RPC failed with HTTP ${response.status} ${response.statusText}`);
  }

  const json = (await response.json()) as FlashbotsRpcResult<T>;
  console.log(`[flashbotsRpc] Raw response: ${JSON.stringify(json)}`);

  if ("error" in json) {
    throw new Error(json.error.message ?? "Unknown Flashbots RPC error");
  }

  if (!("result" in json)) {
    throw new Error("Malformed Flashbots RPC response");
  }

  return json.result;
}

async function sendBundleWithQueue(
  signedBundle: string[],
  targetBlock: number,
  maxBlock: number,
  signer: Wallet
): Promise<string> {
  const body = signedBundle.map((tx) => ({ tx, canRevert: false }));
  const payload = {
    jsonrpc: "2.0",
    id: Date.now(),
    method: "mev_sendBundle",
    params: [
      {
        version: "v0.1",
        inclusion: {
          block: formatBlockTag(targetBlock),
          maxBlock: formatBlockTag(maxBlock)
        },
        body,
        validity: {
          refund: [],
          refundConfig: []
        }
      }
    ]
  };

  console.log(
    `[sendBundleWithQueue] Dispatching bundle targeting ${targetBlock} with maxBlock ${maxBlock}`
  );
  const result = await flashbotsRpc<BundleRpcResult>(payload, signer);
  console.log(`[sendBundleWithQueue] Bundle hash from relay: ${result.bundleHash}`);
  return result.bundleHash;
}

async function waitForBundleInclusion(
  provider: JsonRpcProvider,
  txHashes: string[],
  maxBlock: number
): Promise<TransactionReceipt[] | null> {
  while (true) {
    const currentBlock = await provider.getBlockNumber();
    console.log(`[waitForBundleInclusion] Current block ${currentBlock}, waiting until ${maxBlock}`);
    if (currentBlock > maxBlock) {
      return null;
    }

    const receipts = await Promise.all(
      txHashes.map((hash) => provider.getTransactionReceipt(hash))
    );

    if (receipts.every((receipt): receipt is TransactionReceipt => receipt !== null)) {
      return receipts;
    }

    await delay(RETRY_DELAY_MS);
  }
}

async function logBundleStats(
  bundleHash: string,
  maxBlock: number,
  signer: Wallet
): Promise<void> {
  console.log(
    `Fetching flashbots_getBundleStatsV2 for hash ${bundleHash} through block ${maxBlock}...`
  );
  try {
    const payload = {
      jsonrpc: "2.0",
      id: Date.now(),
      method: "flashbots_getBundleStatsV2",
      params: [
        {
          bundleHash,
          blockNumber: formatBlockTag(maxBlock)
        }
      ]
    };
    const stats = await flashbotsRpc<GetBundleStatsResponseV2>(payload, signer);
    console.log("flashbots_getBundleStatsV2 response:");
    console.log(JSON.stringify(stats, null, 2));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`flashbots_getBundleStatsV2 unavailable: ${message}`);
  }
  console.log(`Flashbots Protect URL: ${FLASHBOTS_STATUS_URL}${bundleHash}`);
}

/**
 * Build, sign, simulate, and send the Flashbots bundle.
 */
async function main() {
  const rpcUrl = requireEnv("SEPOLIA_RPC_URL");
  const contractAddress = requireEnv("CONTRACT_ADDRESS");
  const ownerKey = requireEnv("OWNER_PRIVATE_KEY");
  const buyerKey = requireEnv("BUYER_PRIVATE_KEY");
  const flashbotsKey = requireEnv("FLASHBOTS_SIGNER_KEY");

  const presaleAmount = toBigIntEnv("PRESALE_AMOUNT", "1");
  const bundleBlocksAheadRaw = Number(process.env.BUNDLE_BLOCKS_AHEAD ?? "1");
  const bundleBlocksAhead =
    Number.isFinite(bundleBlocksAheadRaw) && bundleBlocksAheadRaw > 0
      ? Math.floor(bundleBlocksAheadRaw)
      : 1;

  const maxFeePerGas = parseUnits(process.env.MAX_FEE_PER_GAS_GWEI ?? "25", "gwei");
  const maxPriorityFeePerGas = parseUnits(
    process.env.MAX_PRIORITY_FEE_PER_GAS_GWEI ?? "2",
    "gwei"
  );

  if (presaleAmount <= 0n) {
    throw new Error("PRESALE_AMOUNT must be positive");
  }

  const provider = new JsonRpcProvider(rpcUrl);
  // Make sure we are not pointing at the wrong chain.
  const network = await provider.getNetwork();
  if (network.chainId !== 11155111n) {
    console.warn(`Warning: connected chainId ${network.chainId} is not Sepolia (11155111)`);
  }

  const owner = new Wallet(ownerKey, provider);
  console.log(`loading buyerKey ${buyerKey}`)
  const buyer = new Wallet(buyerKey, provider);
  console.log(`buyer loaded ${buyer}`)
  const flashbotsSigner = new Wallet(flashbotsKey, provider);

  const abi = ["function enablePresale()", "function presale(uint256 amount) payable"];
  const iface = new Interface(abi);

  const enableTxRequest: TransactionRequest = {
    to: contractAddress,
    data: iface.encodeFunctionData("enablePresale"),
    type: 2,
    chainId: Number(network.chainId),
    gasLimit: 120_000n,
    maxFeePerGas,
    maxPriorityFeePerGas,
    nonce: await provider.getTransactionCount(owner.address)
  };

  const pricePerToken = parseUnits("0.01", "ether");
  const presaleValue = pricePerToken * presaleAmount;

  const presaleTxRequest: TransactionRequest = {
    to: contractAddress,
    data: iface.encodeFunctionData("presale", [presaleAmount]),
    type: 2,
    chainId: Number(network.chainId),
    gasLimit: 250_000n,
    maxFeePerGas,
    maxPriorityFeePerGas,
    value: presaleValue,
    nonce: await provider.getTransactionCount(buyer.address)
  };

  // Sign both txs offline so the bundle can run atomically.
  const [signedEnableTx, signedPresaleTx] = await Promise.all([
    owner.signTransaction(enableTxRequest),
    buyer.signTransaction(presaleTxRequest)
  ]);

  const enableTxHash = keccak256(signedEnableTx);
  const presaleTxHash = keccak256(signedPresaleTx);

  console.log(`Owner address: ${owner.address}`);
  console.log(`Buyer address: ${buyer.address}`);
  console.log(`Enable presale tx hash: ${enableTxHash}`);
  console.log(`Presale tx hash: ${presaleTxHash}`);

  const flashbotsProvider = await FlashbotsBundleProvider.create(
    provider,
    flashbotsSigner,
    FLASHBOTS_RELAY_URL
  );

  const signedBundle = [signedEnableTx, signedPresaleTx];

  while (true) {
    const blockNumber = await provider.getBlockNumber();
    const targetBlock = blockNumber + 1;
    const maxBlock = targetBlock + bundleBlocksAhead - 1;
    console.log(
      `Targeting block ${targetBlock} with maxBlock ${maxBlock} via mev_sendBundle queue...`
    );

    const simulation = await flashbotsProvider.simulate(signedBundle, targetBlock);
    if (isRelayError(simulation)) {
      console.warn(`Simulation failed for block ${targetBlock}: ${simulation.error.message}`);
      await delay(RETRY_DELAY_MS);
      continue;
    }
    console.log(
      `Simulation ok. Total gas ${simulation.totalGasUsed}, coinbaseDiff ${simulation.coinbaseDiff}`
    );

    let bundleHash: string;
    try {
      bundleHash = await sendBundleWithQueue(signedBundle, targetBlock, maxBlock, flashbotsSigner);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.warn(`Relay rejected bundle for blocks ${targetBlock}-${maxBlock}: ${message}`);
      await delay(RETRY_DELAY_MS);
      continue;
    }

    console.log(`Bundle hash: ${bundleHash}`);

    const receipts = await waitForBundleInclusion(provider, [enableTxHash, presaleTxHash], maxBlock);
    if (!receipts) {
      console.warn(`Bundle not included by block ${maxBlock}. Retrying...`);
      await logBundleStats(bundleHash, maxBlock, flashbotsSigner);
      await delay(RETRY_DELAY_MS);
      continue;
    }

    receipts.forEach((receipt, index) => {
      console.log(
        `Tx ${index + 1} included in block ${receipt.blockNumber} with status ${receipt.status}`
      );
    });

    await logBundleStats(bundleHash, maxBlock, flashbotsSigner);
    console.log("Bundle complete. Output ready.");
    break;
  }
}

main().catch((err) => {
  console.error(`Bundle flow failed: ${err.message ?? err}`);
  process.exit(1);
});
