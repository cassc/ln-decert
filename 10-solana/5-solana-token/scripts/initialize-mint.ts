import * as fs from "fs";
import * as path from "path";
import * as anchor from "@coral-xyz/anchor";
import { Keypair, PublicKey } from "@solana/web3.js";

const METADATA_PROGRAM_ID = new PublicKey(
  "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
);

function readCliArg(flag: string): string | null {
  const argv = process.argv.slice(2);
  const index = argv.indexOf(flag);
  if (index === -1 || index + 1 >= argv.length) {
    return null;
  }
  return argv[index + 1];
}

function loadOrCreateKeypair(filePath: string): Keypair {
  const resolved = path.resolve(filePath);
  if (fs.existsSync(resolved)) {
    const secret = JSON.parse(fs.readFileSync(resolved, "utf-8"));
    return Keypair.fromSecretKey(Uint8Array.from(secret));
  }
  const kp = Keypair.generate();
  fs.mkdirSync(path.dirname(resolved), { recursive: true });
  fs.writeFileSync(resolved, JSON.stringify(Array.from(kp.secretKey)));
  console.log(`Saved new mint keypair to ${resolved}`);
  return kp;
}

async function main() {
  const decimalsRaw = readCliArg("--decimals");
  const name = readCliArg("--name");
  const symbol = readCliArg("--symbol");
  const uri = readCliArg("--uri");
  const mintPath = readCliArg("--mint-keypair");

  if (!decimalsRaw || !name || !symbol || !uri || !mintPath) {
    console.error(
      "Usage: npm run initialize-mint -- --mint-keypair <file> --decimals <number> --name <string> --symbol <string> --uri <string>"
    );
    process.exit(1);
  }

  const decimals = Number(decimalsRaw);
  if (!Number.isInteger(decimals) || decimals < 0 || decimals > 18) {
    console.error("decimals must be an integer between 0 and 18");
    process.exit(1);
  }

  anchor.setProvider(anchor.AnchorProvider.env());
  const provider = anchor.getProvider() as anchor.AnchorProvider & {
    wallet: anchor.Wallet;
  };
  const program = anchor.workspace
    .SolanaToken as anchor.Program<any>;

  const mintKeypair = loadOrCreateKeypair(mintPath);

  const [metadataPda] = PublicKey.findProgramAddressSync(
    [
      Buffer.from("metadata"),
      METADATA_PROGRAM_ID.toBuffer(),
      mintKeypair.publicKey.toBuffer(),
    ],
    METADATA_PROGRAM_ID
  );

  console.log("Sending initialize_mint...");
  const tx = await program.methods
    .initializeMint(decimals, name, symbol, uri)
    .accounts({
      payer: provider.wallet.publicKey,
      authority: provider.wallet.publicKey,
      mint: mintKeypair.publicKey,
      metadata: metadataPda,
    })
    .signers([mintKeypair])
    .rpc();

  console.log("Transaction signature:", tx);
  console.log("Mint pubkey:", mintKeypair.publicKey.toBase58());
  console.log("Metadata PDA:", metadataPda.toBase58());
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
