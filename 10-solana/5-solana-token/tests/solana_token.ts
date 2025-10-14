import * as anchor from "@coral-xyz/anchor";
import { AnchorError, Program } from "@coral-xyz/anchor";
import { Keypair, PublicKey, SystemProgram } from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, getAccount, getOrCreateAssociatedTokenAccount } from "@solana/spl-token";
import { expect } from "chai";
import { SolanaToken } from "../target/types/solana_token";

describe("solana_token", () => {
  anchor.setProvider(anchor.AnchorProvider.env());

  const provider = anchor.getProvider<anchor.AnchorProvider>();
  const program = anchor.workspace.SolanaToken as Program<SolanaToken>;

  const wallet = provider.wallet as anchor.Wallet & { payer: Keypair };

  it("initializes the mint and mints tokens", async () => {
    const mintKeypair = Keypair.generate();
    const [statePda] = PublicKey.findProgramAddressSync(
      [Buffer.from("token-state"), mintKeypair.publicKey.toBuffer()],
      program.programId,
    );
    const decimals = 6;

    await program.methods
      .initializeMint(decimals)
      .accounts({
        payer: provider.wallet.publicKey,
        authority: provider.wallet.publicKey,
        state: statePda,
        mint: mintKeypair.publicKey,
        systemProgram: SystemProgram.programId,
        tokenProgram: TOKEN_PROGRAM_ID,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      })
      .signers([mintKeypair])
      .rpc();

    const stateAccount = await program.account.tokenState.fetch(statePda);
    expect(stateAccount.mint.toBase58()).to.equal(mintKeypair.publicKey.toBase58());
    expect(stateAccount.authority.toBase58()).to.equal(provider.wallet.publicKey.toBase58());
    expect(stateAccount.decimals).to.equal(decimals);

    const recipientAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      wallet.payer,
      mintKeypair.publicKey,
      provider.wallet.publicKey,
    );

    const mintAmount = new anchor.BN(1_000_000);

    await program.methods
      .mintTokens(mintAmount)
      .accounts({
        authority: provider.wallet.publicKey,
        state: statePda,
        mint: mintKeypair.publicKey,
        recipient: recipientAta.address,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .rpc();

    const tokenAccount = await getAccount(provider.connection, recipientAta.address, "confirmed");
    expect(tokenAccount.amount).to.equal(BigInt(mintAmount.toString()));

    const badAuthority = Keypair.generate();

    try {
      await program.methods
        .mintTokens(new anchor.BN(1))
        .accounts({
          authority: badAuthority.publicKey,
          state: statePda,
          mint: mintKeypair.publicKey,
          recipient: recipientAta.address,
          tokenProgram: TOKEN_PROGRAM_ID,
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
