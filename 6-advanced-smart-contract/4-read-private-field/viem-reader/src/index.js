import 'dotenv/config';
import { createPublicClient, http, keccak256, toHex } from 'viem';
import { sepolia } from 'viem/chains';

const rpcUrl = process.env.RPC_URL ?? sepolia.rpcUrls.default.http[0];
const contractAddress = process.env.CONTRACT_ADDRESS;

if (!contractAddress) {
  console.error('Set CONTRACT_ADDRESS in .env before running this script.');
  process.exit(1);
}

const client = createPublicClient({
  chain: sepolia,
  transport: http(rpcUrl),
});

const LENGTH_SLOT = 0n; // _locks array is declared at slot 0
const SLOTS_PER_ENTRY = 2n; // Each LockInfo struct uses 2 storage slots (slot 0: user+startTime packed, slot 1: amount)
// ADDRESS_MASK = all 1s for lowest 160 bits (40 hex digits = 20 bytes)
// Used to extract address by: packedValues & ADDRESS_MASK (keeps lowest 160 bits, zeros out the rest)
const ADDRESS_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFn;
// UINT64_MASK = all 1s for lowest 64 bits (16 hex digits = 8 bytes)
// Used to extract uint64 by: (packedValues >> 160) & UINT64_MASK (shift right 160 bits, then keep lowest 64 bits)
const UINT64_MASK = 0xFFFFFFFFFFFFFFFFn;

const slotToHex = (slot) => toHex(slot, { size: 32 });

async function main() {
  // Step 1: Read the array length from slot 0
  const lengthHex = await client.getStorageAt({
    address: contractAddress,
    slot: slotToHex(LENGTH_SLOT),
  });
  const length = Number(BigInt(lengthHex));

  if (length === 0) {
    console.log('No locks in storage.');
    return;
  }

  // Step 2: Calculate the base slot where array elements are stored
  // For dynamic arrays, elements are stored starting at keccak256(array_slot)
  const baseSlot = BigInt(
    keccak256(slotToHex(LENGTH_SLOT)),
  );

  // Step 3: Iterate through each array element
  for (let i = 0; i < length; i++) {
    // Calculate the starting slot for this struct (each struct uses SLOTS_PER_ENTRY slots)
    const structSlot = baseSlot + BigInt(i) * SLOTS_PER_ENTRY;

    // Read slot 0 of the struct: contains packed user (address) and startTime (uint64)
    const packedValuesHex = await client.getStorageAt({
      address: contractAddress,
      slot: slotToHex(structSlot),
    });
    // Read slot 1 of the struct: contains amount (uint256)
    const amountHex = await client.getStorageAt({
      address: contractAddress,
      slot: slotToHex(structSlot + 1n),
    });

    const packedValues = BigInt(packedValuesHex);
    const amount = BigInt(amountHex);

    // Extract user (lowest 160 bits) from packed values
    const user = `0x${(packedValues & ADDRESS_MASK).toString(16).padStart(40, '0')}`;
    // Extract startTime (bits 160-223) by shifting right 160 bits then masking
    const startTime = Number((packedValues >> 160n) & UINT64_MASK);

    console.log(`locks[${i}]: user:${user},startTime:${startTime},amount:${amount}`);
  }
}

main().catch((error) => {
  console.error('Failed to read storage:', error);
  process.exit(1);
});
