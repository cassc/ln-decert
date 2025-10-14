import * as anchor from "@coral-xyz/anchor";
import { BN, Program } from "@coral-xyz/anchor";
import { getOrCreateAssociatedTokenAccount, TOKEN_PROGRAM_ID } from "@solana/spl-token";
import { Keypair, PublicKey, SystemProgram } from "@solana/web3.js";
import * as fs from "fs";
import * as path from "path";
import { SolanaToken } from "../target/types/solana_token";

const STATE_SEED = Buffer.from("token-state");
const DEFAULT_DECIMALS = 6;
const DEPLOY_DIR = path.join(__dirname, "..", "target", "deploy");
const MINT_KEYPAIR_PATH = path.join(DEPLOY_DIR, "token-mint-keypair.json");

module.exports = async function (provider: anchor.AnchorProvider) {
  anchor.setProvider(provider);

  const program = anchor.workspace.SolanaToken as Program<SolanaToken>;
  const wallet = provider.wallet as anchor.Wallet & { payer: Keypair };

  const decimals = Number(process.env.TOKEN_DECIMALS ?? DEFAULT_DECIMALS);
  const initialSupplyRaw = process.env.INITIAL_SUPPLY;
  const initialSupply = initialSupplyRaw ? BigInt(initialSupplyRaw) : 0n;

  const mintKeypair = Keypair.generate();
  const [statePda] = PublicKey.findProgramAddressSync(
    [STATE_SEED, mintKeypair.publicKey.toBuffer()],
    program.programId,
  );

  await program.methods
    .initializeMint(decimals)
    .accounts({
      payer: wallet.publicKey,
      authority: wallet.publicKey,
      state: statePda,
      mint: mintKeypair.publicKey,
      systemProgram: SystemProgram.programId,
      tokenProgram: TOKEN_PROGRAM_ID,
      rent: anchor.web3.SYSVAR_RENT_PUBKEY,
    })
    .signers([mintKeypair])
    .rpc();

  fs.mkdirSync(DEPLOY_DIR, { recursive: true });
  fs.writeFileSync(MINT_KEYPAIR_PATH, JSON.stringify(Array.from(mintKeypair.secretKey)));

  const ata = await getOrCreateAssociatedTokenAccount(
    provider.connection,
    wallet.payer,
    mintKeypair.publicKey,
    wallet.publicKey,
  );

  if (initialSupply > 0) {
    await program.methods
      .mintTokens(new BN(initialSupply.toString()))
      .accounts({
        authority: wallet.publicKey,
        state: statePda,
        mint: mintKeypair.publicKey,
        recipient: ata.address,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .rpc();
  }

  console.log("Mint initialized at:", mintKeypair.publicKey.toBase58());
  console.log("State PDA:", statePda.toBase58());
  console.log("Associated token account:", ata.address.toBase58());
  console.log("Mint keypair saved to:", MINT_KEYPAIR_PATH);

  if (initialSupply > 0) {
    console.log(`Minted ${initialSupply} base units to the wallet ATA.`);
  }
};
