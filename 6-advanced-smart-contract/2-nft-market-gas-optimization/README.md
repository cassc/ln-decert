# NFT Market – Gas Optimization

This folder copies the baseline project located at `ln-decert/3-openzepplin-token/nft-market`.
For the complete introduction, deployment scripts, and usage details, read the
[original README](../../3-openzepplin-token/nft-market/README.md).
The notes here only describe the gas-focused adjustments made in this fork.

## Gas Optimization Notes

- `Listing.price` now uses `uint96`, letting the struct occupy one storage slot and lowering the `list`/`getListing` storage cost.
- `_consumeListing`, `list`, `getListing`, and `unlist` reuse storage pointers instead of copying structs into memory.
- All revert paths were converted to custom errors (`NotOwner`, `InvalidData`, etc.), shrinking bytecode and making reverts cheaper.
- `tokensReceived` and `buyNFT` rely on the boolean return values of `transfer`/`transferFrom` and reuse the same custom errors on failure.
