# Solana Counter App

## Prerequisites

- [Rust](https://www.rust-lang.org/tools/install)
- [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools)
- [Anchor Framework](https://www.anchor-lang.com/docs/installation)

## Installation

```bash
# Clone the repository
git clone https://github.com/cassc/sol-counter-app.git
cd sol-counter-app

# Install dependencies
npm install
```

## Build

```bash
# Build the program
anchor build
```

## Test

```bash
# Run tests
anchor test
```

## Deploy

```bash
# Deploy to devnet
anchor deploy --provider.cluster devnet

# Update the program ID in lib.rs and Anchor.toml with the deployed address
```

## Usage Example

```typescript
// Initialize a counter
await program.methods
  .initialize()
  .accounts({
    counter: counterPda,
    user: userWallet.publicKey,
    systemProgram: SystemProgram.programId,
  })
  .rpc();

// Increment the counter
await program.methods
  .increment()
  .accounts({
    counter: counterPda,
    user: userWallet.publicKey,
  })
  .rpc();
```

## Program ID

```
AxEx7K72AZiwkxgwxw3KkEtjAc6ezdPxcYK3zFJd3Qgu
```

> **Note**: Replace this with your actual program ID after deployment

## Project Structure

```
.
├── programs/
│   └── counter-app/
│       └── src/
│           └── lib.rs          # Main program logic
├── tests/
│   └── counter-app.ts          # Integration tests
├── migrations/
│   └── deploy.ts               # Deployment script
├── Anchor.toml                 # Anchor configuration
└── package.json                # Node dependencies
```

## Error Handling

The program includes custom error codes:

- **Unauthorized**: Thrown when a non-authority tries to increment the counter
- **NumericalOverflow**: Protection against counter overflow

## Recent Updates

- Fixed bumps API usage to use direct field access (`ctx.bumps.counter`) instead of deprecated `.get()` method
- Updated for Anchor 0.31.1 compatibility

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Resources

- [Anchor Documentation](https://www.anchor-lang.com/)
- [Solana Documentation](https://docs.solana.com/)
- [Solana Cookbook](https://solanacookbook.com/)
