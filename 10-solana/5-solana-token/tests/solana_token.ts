import * as anchor from "@coral-xyz/anchor";
import { AnchorError, Program } from "@coral-xyz/anchor";
import { Keypair, PublicKey, SystemProgram } from "@solana/web3.js";
import {
  TOKEN_PROGRAM_ID,
  getAccount,
  getOrCreateAssociatedTokenAccount,
} from "@solana/spl-token";
import { expect } from "chai";
import { SolanaToken } from "../target/types/solana_token";

const METADATA_PROGRAM_ID = new PublicKey(
  "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
);

describe("solana_token", () => {
  anchor.setProvider(anchor.AnchorProvider.env());

  const provider = anchor.getProvider();
  const program = anchor.workspace.SolanaToken as Program<SolanaToken>;

  const wallet = provider.wallet as anchor.Wallet & { payer: Keypair };

  it("initializes the mint and mints tokens", async () => {
    const mintKeypair = Keypair.generate();
    const [statePda] = PublicKey.findProgramAddressSync(
      [Buffer.from("token-state"), mintKeypair.publicKey.toBuffer()],
      program.programId
    );
    const decimals = 18;

    // Derive metadata PDA
    const [metadataPda] = PublicKey.findProgramAddressSync(
      [
        Buffer.from("metadata"),
        METADATA_PROGRAM_ID.toBuffer(),
        mintKeypair.publicKey.toBuffer(),
      ],
      METADATA_PROGRAM_ID
    );

    const tokenName = "My Test Token";
    const tokenSymbol = "MTT";
    const tokenUri = "https://example.com/token-metadata.json";

    await program.methods
      .initializeMint(decimals, tokenName, tokenSymbol, tokenUri)
      .accounts({
        payer: provider.wallet.publicKey,
        authority: provider.wallet.publicKey,
        mint: mintKeypair.publicKey,
        metadata: metadataPda,
      })
      .signers([mintKeypair])
      .rpc();

    const stateAccount = await program.account.tokenState.fetch(statePda);
    expect(stateAccount.mint.toBase58()).to.equal(
      mintKeypair.publicKey.toBase58()
    );
    expect(stateAccount.authority.toBase58()).to.equal(
      provider.wallet.publicKey.toBase58()
    );
    expect(stateAccount.decimals).to.equal(decimals);

    // Verify metadata account was created
    const metadataAccount = await provider.connection.getAccountInfo(
      metadataPda
    );
    expect(metadataAccount).to.not.be.null;
    console.log(
      "Metadata account created successfully at:",
      metadataPda.toBase58()
    );

    const recipientAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      wallet.payer,
      mintKeypair.publicKey,
      provider.wallet.publicKey
    );

    const mintAmount = new anchor.BN(1_000_000);

    const mintTx = await program.methods
      .mintTokens(mintAmount)
      .accounts({
        authority: provider.wallet.publicKey,
        mint: mintKeypair.publicKey,
        recipient: recipientAta.address,
      })
      .rpc();

    // Wait for transaction confirmation
    await provider.connection.confirmTransaction(mintTx, "confirmed");

    const tokenAccount = await getAccount(
      provider.connection,
      recipientAta.address,
      "confirmed"
    );
    expect(tokenAccount.amount).to.equal(BigInt(mintAmount.toString()));

    const badAuthority = Keypair.generate();

    try {
      await program.methods
        .mintTokens(new anchor.BN(1))
        .accounts({
          authority: badAuthority.publicKey,
          recipient: recipientAta.address,
          mint: mintKeypair.publicKey,
        })
        .signers([badAuthority])
        .rpc();
      expect.fail("Unauthorized mint should have failed");
    } catch (error) {
      expect(error).to.be.instanceOf(AnchorError);
      const anchorError = error as AnchorError;
      expect(anchorError.error.errorCode.code).to.equal("Unauthorized");
    }
  });
});
