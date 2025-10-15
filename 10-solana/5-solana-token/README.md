# Prepare your deployment

```bash
pnpm i
anchor build
```


# Initialize Mint

- ANCHOR_WALLET: Path to your Solana wallet keypair file, the signer will become the mint authority.
- mint-keypair: Path to the keypair file for the new mint, this file will be created if it does not exist.

Test the mint initialization locally:

> Don't set too large `decimals` value! SPL tokens are hard-capped at u64::MAX.
> With 18 decimals, that caps total supply to ≈18.4 tokens.
> Use fewer decimals to get realistic supply ranges.


```bash
ANCHOR_PROVIDER_URL=http://localhost:8899 ANCHOR_WALLET=~/.config/solana/id.json npm run initialize-mint -- --mint-keypair ~/.config/solana/otter-mint.json --decimals 9 --name OTTER --symbol OTR --uri https://example.com
```


```bash
ANCHOR_PROVIDER_URL=https://api.devnet.solana.com \
ANCHOR_WALLET=~/.config/solana/id.json \
npm run initialize-mint -- \
  --mint-keypair ~/.config/solana/otter-mint.json \
  --decimals 9 \
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
Rent Epoch: 9446744073709551615
Length: 82 (0x52) bytes
0000:   01 00 00 00  8d 0f cc c2  ed cf 19 26  ff f7 91 c6   ...........&....
0010:   77 d4 5d f9  d0 0b e6 90  4f d5 62 0f  52 8f 92 8d   w.].....O.b.R...
0020:   d8 06 0c ac  00 00 00 00  00 00 00 00  12 01 01 00   ................
0030:   00 00 8d 0f  cc c2 ed cf  19 26 ff f7  91 c6 77 d4   .........&....w.
0040:   5d f9 d0 0b  e6 90 4f d5  62 0f 52 8f  92 8d d8 06   ].....O.b.R.....
0050:   0c ac                                                ..
```


# Get the metadata json 

Check the metadata created on line https://solscan.io/token/AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM?cluster=devnet or using `metaboss`:

```bash
metaboss decode mint --account AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM --rpc https://api.devnet.solana.com
# this downloads the metadata json file,
cat ./AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM.json
{
  "name": "OTTER",
  "symbol": "OTR",
  "uri": "https://sapphire-efficient-penguin-931.mypinata.cloud/ipfs/bafkreia7k3l56pa64drdknd4lfneyze2iyfmtvbg6szrnabl6c7tbvm7qu",
  "seller_fee_basis_points": 0,
  "creators": null
}
```


# Mint tokens

```bash
ANCHOR_PROVIDER_URL=https://api.devnet.solana.com \
ANCHOR_WALLET=~/.config/solana/id.json \
npm run mint-tokens -- \
  --mint AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM \
  --amount 10000000000000000000000000
```

# Check the current total supply

```bash
spl-token supply AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM --url https://api.devnet.solana.com
```


# Check balance of the mint authority wallet:



Check the token balance:

```bash
# Check for token balances for an account:
spl-token accounts --owner DJdGzJ6xNuA3UPikq5bqoYDB3DVsag8EAgFndfWthdLh --url https://api.devnet.solana.com

Token                                         Balance
-----------------------------------------------------
CXk2AMBfi3TwaEL2468s6zP8xq9NxTXjp9gjMgzeUynM  100  // this is an existing token account, showing the mint address and the balance


# Create an associated token account (ATA) for the new mint if you don't have one already:
spl-token create-account AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM --url https://api.devnet.solana.com

spl-token balance AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM --url https://api.devnet.solana.com
```

# Transfer tokens to another wallet

Notice the amount is in the store amount, so for 9 decimals, 0.05 tokens is 50_000_000 units.


```bash
# spl-token transfer <mint> <amount> <recipient> [--fund-recipient] [--allow-unfunded-recipient]
spl-token transfer AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM 0.05 58pDLP9LrRHfitc9eRCGwfi6Ed8eB2DFMPrtcnB9fwEf --fund-recipient --allow-unfunded-recipient
```

# List holders of the token

Use the json-rpc API directly:

```bash
curl https://api.devnet.solana.com -X POST -H "Content-Type: application/json" -d '{
  "jsonrpc":"2.0",
  "id":1,
  "method":"getProgramAccounts",
  "params":[
    "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
    {
      "encoding":"jsonParsed",
      "filters":[
        {"dataSize":165},
        {"memcmp":{"offset":0,"bytes":"AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM"}}
      ]
    }
  ]
}'

{"jsonrpc":"2.0","result":[{"account":{"data":{"parsed":{"info":{"isNative":false,"mint":"AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM","owner":"DJdGzJ6xNuA3UPikq5bqoYDB3DVsag8EAgFndfWthdLh","state":"initialized","tokenAmount":{"amount":"11950000000000000000","decimals":18,"uiAmount":11.95,"uiAmountString":"11.95"}},"type":"account"},"program":"spl-token","space":165},"executable":false,"lamports":2039280,"owner":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA","rentEpoch":18446744073709551615,"space":165},"pubkey":"BRLBnKr3EgYrhCqgbtZB7atko5ZQTiRAwG7zd9nPMxFx"},{"account":{"data":{"parsed":{"info":{"isNative":false,"mint":"AGr1g5EBjWNqUiDkfJiBVKgDg7d9tkP3T5qxpzHtcgjM","owner":"58pDLP9LrRHfitc9eRCGwfi6Ed8eB2DFMPrtcnB9fwEf","state":"initialized","tokenAmount":{"amount":"50000000000000000","decimals":18,"uiAmount":0.05,"uiAmountString":"0.05"}},"type":"account"},"program":"spl-token","space":165},"executable":false,"lamports":2039280,"owner":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA","rentEpoch":18446744073709551615,"space":165},"pubkey":"9hxnr7uzWPKh1E9Jj2H8MnSM3z4jjyjSjkUraZi1dHBc"}],"id":1}
```