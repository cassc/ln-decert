import * as anchor from "@coral-xyz/anchor";
import { getOrCreateAssociatedTokenAccount } from "@solana/spl-token";
import { Keypair, PublicKey, Transaction } from "@solana/web3.js";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

type WalletWithPayer = anchor.Wallet & { payer: Keypair };

function readCliArg(flag: string): string | null {
  const argv = process.argv.slice(2);
  const index = argv.indexOf(flag);
  if (index === -1 || index + 1 >= argv.length) {
    return null;
  }
  return argv[index + 1];
}

function printUsage(): never {
  console.error(
    "Usage: npm run mint-tokens -- --mint <pubkey> --amount <integer> [--owner <pubkey>] [--recipient <token-account>]"
  );
  process.exit(1);
}

async function main() {
  const mintArg = readCliArg("--mint");
  const amountArg = readCliArg("--amount");
  const ownerArg = readCliArg("--owner");
  const recipientArg = readCliArg("--recipient");

  if (!mintArg || !amountArg) {
    printUsage();
  }

  const BN = (anchor as any).BN ?? (anchor as any).default?.BN;

  if (!BN) {
    console.error("Unable to locate Anchor BN constructor");
    process.exit(1);
  }

  let amount: any;
  try {
    amount = new BN(amountArg!, 10);
  } catch (e) {
    console.error(`--amount ${amountArg} must be a base-10 integer string ${e}`);
    process.exit(1);
  }

  anchor.setProvider(anchor.AnchorProvider.env());
  const provider = anchor.getProvider() as anchor.AnchorProvider;
  const wallet = provider.wallet as WalletWithPayer;

  const programId = new PublicKey("ErdLiDbat2pkpij1ykatMERv2hkFmv6V8RgC77jfFcCD");

  const workspaceProgram = (anchor.workspace as Record<string, unknown>)
    .SolanaToken as anchor.Program | undefined;

  let programForIx: anchor.Program;

  if (workspaceProgram) {
    programForIx = workspaceProgram;
  } else {
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const idlPath = path.resolve(__dirname, "../target/idl/solana_token.json");
    if (!fs.existsSync(idlPath)) {
      console.error("solana_token IDL not found at", idlPath);
      process.exit(1);
    }
    const idl = JSON.parse(fs.readFileSync(idlPath, "utf8"));
    if (!idl.address) {
      idl.address = programId.toBase58();
    }
    if (Array.isArray(idl.accounts)) {
      const typeMap = new Map(
        (idl.types ?? []).map((t: { name: string; type: unknown }) => [
          t.name,
          t.type,
        ])
      );
      idl.accounts = idl.accounts.map((account: any) => {
        if (!account.type && typeMap.has(account.name)) {
          account.type = typeMap.get(account.name);
        }
        if (account.name === "TokenState" && account.size === undefined) {
          account.size = 74;
        }
        return account;
      });
    }
    programForIx = new anchor.Program(idl, programId, provider);
  }

  const mint = new PublicKey(mintArg);

  let recipient: PublicKey;
  if (recipientArg) {
    recipient = new PublicKey(recipientArg);
  } else {
    const owner = ownerArg ? new PublicKey(ownerArg) : wallet.publicKey;
    const ata = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      wallet.payer,
      mint,
      owner
    );
    recipient = ata.address;
    console.log(
      `Using ATA ${recipient.toBase58()} for owner ${owner.toBase58()}`
    );
  }

  const [statePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("token-state"), mint.toBuffer()],
    programId
  );

  console.log("Sending mint_tokens...");
  console.log("Using program", programId.toBase58());

  const methodBuilder = programForIx.methods
    .mintTokens(amount)
    .accounts({
      authority: wallet.publicKey,
      state: statePda,
      mint,
      recipient,
    })
    .remainingAccounts([]);

  const ix = await methodBuilder.instruction();
  ix.programId = programId;
  console.log("Instruction program id", ix.programId.toBase58());

  const tx = new Transaction().add(ix);
  const signature = await provider.sendAndConfirm(tx, [], {
    commitment: "confirmed",
  });

  console.log("Transaction signature:", signature.signature ?? signature);
  console.log("Recipient token account:", recipient.toBase58());
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
