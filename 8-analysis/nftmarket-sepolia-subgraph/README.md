# NFTMarket (Sepolia) — Subgraph

Indexes `Listed`, `Unlisted`, and `Purchase` events from
`0xDDf4600e91257383A551546946777B144E03416c` on **Sepolia**, and links each
`Sale` to its originating `Listing` (one-to-one).

## Prereqs
- Node 18+
- pnpm 8+
- `@graphprotocol/graph-cli` (installed by `pnpm add -g @graphprotocol/graph-cli`)

## Install
```bash
pnpm install
```

## Codegen & Build

```bash
pnpm run codegen
pnpm run build
```

## Deploy (Subgraph Studio)

1. Auth graph query using the API key:

   ```bash
graph auth <the-graph-api-key>
   ```
2. Build and deploy:

   ```bash
graph codegen && graph build
graph deploy my-nft-market-events
   ```

## Query examples

### Active listings

```graphql
{
  listings(where:{status: ACTIVE}, orderBy: createdAtTimestamp, orderDirection: desc) {
    id nft tokenId seller price status
  }
}
```

### Recent sales with their listing

```graphql
{
  sales(first: 10, orderBy: timestamp, orderDirection: desc) {
    id buyer seller price timestamp
    listing { id seller price status }
  }
}
```

### By account (lowercased address)

```graphql
{
  account(id:"0x...") {
    purchases { id nft tokenId price timestamp }
    sales { id nft tokenId price timestamp }
  }
}
```

## Notes

* `startBlock` in `subgraph.yaml` is set to `9362208`. Adjust if you want faster sync (move near the first `Listed` tx).
* Entity IDs:

  * `Listing.id = ${nft}-${tokenId}` (lowercased nft).
  * `Sale.id = ${txHash}-${logIndex}` to ensure uniqueness.
* Addresses are consistently lowercased to avoid duplicates.

