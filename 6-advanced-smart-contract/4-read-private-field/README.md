## Overview



Repository structure:

```
.
├── src
│   └── EsRNT.sol              (esRNT contract with 11-item _locks array)
├── script
│   └── DeployEsRNT.s.sol      (deployment script)
└── viem-reader/               (Viem getStorageAt reader for _locks)
```


## Foundry workflow

```bash
forge build   # compile
forge test    # run the EsRNTTest suite
```

Deploy to Sepolia (needs funded key + RPC URL):

```bash
export PRIVATE_KEY=0xabc...      # funded Sepolia key
export RPC_URL=https://...       # Sepolia RPC endpoint
# remove `--broadcast` if you only need a dry run.
forge script script/DeployEsRNT.s.sol:DeployEsRNTScript \
  --rpc-url $RPC_URL --broadcast  --verify --verifier blockscout  --verifier-url https://eth-sepolia.blockscout.com/api 

# or verify after deployment with:
forge verify-contract 0xabc... src/EsRNT.sol:esRNT --chain sepolia --verifier blockscout --verifier-url https://eth-sepolia.blockscout.com/api 
```


## Viem reader

```bash
cd viem-reader
cp .env.example .env             # set RPC_URL + CONTRACT_ADDRESS
pnpm install                     # already done once, run again if deps change
pnpm start                       # prints every lock: user, startTime, amount
```

The script computes the `_locks` storage slots, calls `getStorageAt` for each one, and prints
`locks[i]: user:..., startTime:..., amount:...` in decimal form.
