const anchor = require("@coral-xyz/anchor");

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.counterApp;
  if (!program) {
    throw new Error("Program counterApp is not found in the workspace. Build the program with `anchor build` first.");
  }

  const user = provider.wallet.publicKey;
  const [counterPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("counter"), user.toBuffer()],
    program.programId
  );

  let counterAccount;
  try {
    counterAccount = await program.account.counter.fetch(counterPda);
    console.log(`Counter already initialized. Current value: ${counterAccount.count.toString()}`);
  } catch (error) {
    const missingAccount =
      error.message?.includes("Account does not exist") || error.toString().includes("Account does not exist");
    if (missingAccount) {
      console.log("Counter account not found. Initializing...");
      await program.methods
        .initialize()
        .accounts({
          counter: counterPda,
          user,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .rpc();
      counterAccount = await program.account.counter.fetch(counterPda);
      console.log(`Counter initialized. Current value: ${counterAccount.count.toString()}`);
    } else {
      throw error;
    }
  }

  const signature = await program.methods
    .increment()
    .accounts({
      counter: counterPda,
      user,
    })
    .rpc();
  console.log("Increment transaction signature:", signature);

  counterAccount = await program.account.counter.fetch(counterPda);
  console.log(`Counter value after increment: ${counterAccount.count.toString()}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
