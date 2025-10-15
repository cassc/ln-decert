# Prepare your deployment

```bash
pnpm i
anchor build
```


# Initialize Mint

- ANCHOR_WALLET: Path to your Solana wallet keypair file, the signer will become the mint authority.
- mint-keypair: Path to the keypair file for the new mint, this file will be created if it does not exist.

Test the mint initialization locally:

```bash
ANCHOR_PROVIDER_URL=http://localhost:8899 ANCHOR_WALLET=~/.config/solana/id.json npm run initialize-mint -- --mint-keypair ~/.config/solana/otter-mint.json --decimals 18 --name OTTER --symbol OTR --uri https://example.com
```


```bash
ANCHOR_PROVIDER_URL=https://api.devnet.solana.com \
ANCHOR_WALLET=~/.config/solana/id.json \
npm run initialize-mint -- \
  --mint-keypair ~/.config/solana/otter-mint.json \
  --decimals 18 \
  --name "OTTER" \
  --symbol "OTR" \
  --uri "https://sapphire-efficient-penguin-931.mypinata.cloud/ipfs/bafkreia7k3l56pa64drdknd4lfneyze2iyfmtvbg6szrnabl6c7tbvm7qu"

Sending initialize_mint...
Transaction signature: 3uH69ekawhsJbhDvytbrBCJKZg1LKXtVdEVyzwqnZRRjnTN9uPMtYRX48tikgy3rsWuRGr174dpMFMADGWguci2z
Mint pubkey: AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM
Metadata PDA: 4Kb4ZsMmnhS95ndVz1V7chCCfZjhTzoLvZ5ejHovCBJn
```

Check the deployed account:

```bash
solana account AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM --url https://api.devnet.solana.com

Public Key: AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM
Balance: 0.0014616 SOL
Owner: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
Executable: false
Rent Epoch: 18446744073709551615
Length: 82 (0x52) bytes
0000:   01 00 00 00  8d 0f cc c2  ed cf 19 26  ff f7 91 c6   ...........&....
0010:   77 d4 5d f9  d0 0b e6 90  4f d5 62 0f  52 8f 92 8d   w.].....O.b.R...
0020:   d8 06 0c ac  00 00 00 00  00 00 00 00  12 01 01 00   ................
0030:   00 00 8d 0f  cc c2 ed cf  19 26 ff f7  91 c6 77 d4   .........&....w.
0040:   5d f9 d0 0b  e6 90 4f d5  62 0f 52 8f  92 8d d8 06   ].....O.b.R.....
0050:   0c ac                                                ..
```

Check the metadata created:

```bash
metaboss show-metadata --mint AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM --rpc https://api.devnet.solana.com
```