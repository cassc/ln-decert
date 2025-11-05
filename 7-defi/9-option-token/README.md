# Option Token Lab

[中文版](README.zh-CN.md) | English

This project shows how to build a simple European call option token with Foundry. The goal is to learn how a project can mint option tokens by locking ETH, let users exercise on expiry day, and clean up the position after the window closes.

## Core idea
- Strike price and expiry are fixed when you deploy the contract.
- The project owner (seller) locks ETH collateral and mints one option token per wei of ETH.
- Buyers pay the option premium to the seller outside this contract (for example via a separate marketplace) before the seller mints tokens to them.
- Option holders pay the strike asset (mock USD in tests) to receive ETH during the exercise window.
- After the window the seller can reclaim any leftover ETH, mark the market as expired, and burn the remaining tokens.

## Roles
- **Project owner** deposits ETH to mint tokens, withdraws strike proceeds, and closes the market after expiry.
- **User** holds option tokens, pays the strike asset during the exercise window, and receives ETH.
- **Liquidity bootstrapping (optional)**: the owner can seed an `ocETH/USDT` or `ocETH/USDC` pool at a low premium so users can buy options cheaply in advance.

## Contract features
- European style: exercise is only allowed between `expiry` and `expiry + exerciseWindow`.
- Full collateral: each token represents 1 wei of ETH locked in the contract.
- Strike settlement: strike amounts use 18 decimal math so you can plug in Chainlink feeds or custom quotes.
- Post-expiry cleanup: transfers stop after settlement and the owner can burn leftover tokens holder by holder.
- Liquidity bootstrap: the owner can move freshly minted options plus strike tokens to a pool via `seedLiquidity`.
- Event logs for mint, exercise, strike withdrawal, liquidity seeding, and collateral reclaim make back-testing and indexing easy.

### Premium settlement flow
1. Quote a premium in the strike asset for each option token.
2. Collect that premium from the buyer through any workflow outside this contract (e.g., escrow or marketplace contract).
3. Once payment is received, call `mintOptions` and send the tokens to the buyer.
4. (Optional) Use `seedLiquidity` to pair a portion of the minted options with strike asset in a DEX so future buyers can trade against a live pool.

### Parameters to pick
- **Strike price**: set once at deploy time. In production you would read ETH/USD from Chainlink like Lyra does.
- **Exercise window**: keep it short (for example 24h) to reduce idle collateral.
- **Strike asset**: any ERC20 stable coin (USDC/USDT/DAI). The tests use a mock token named `mUSD`.

### Exercise math
- Tokens minted = ETH deposited (1 ether → 1e18 tokens).
- Strike due = `amount * strikePrice / 1e18`.
- If a user exercises half their balance the contract keeps the rest of the collateral for other holders.

## Development quickstart

```bash
# install dependencies
forge install

# format and run tests
forge fmt
forge test

# deploy script (set env vars before running)
OWNER=0x... \
STRIKE_ASSET=0x... \
STRIKE_PRICE=2000e18 \
EXPIRY=$(date -d "+7 days" +%s) \
EXERCISE_WINDOW=$((24*60*60)) \
forge script script/DeployOptionToken.s.sol:DeployOptionToken --rpc-url <RPC> --broadcast
```

## Test coverage
- Owner only minting.
- Exercise before expiry reverts.
- Exercise inside the window moves strike tokens and ETH.
- Exercise after the window reverts.
- Owner withdrawals for strike tokens and late collateral.
- Burning expired balances works only for the owner.
- Liquidity seeding helper transfers both legs to an external pool and rejects invalid inputs.

## Stretch ideas for further learning
- Plug a Chainlink ETH/USD feed to auto set strike or to block exercise when the oracle is stale.
- Write a premium calculator and seed a Uniswap V3 pool, similar to Panoptic.
- Add support for ERC20 collateral (WETH) instead of raw ETH for compatibility with vault systems.
- Track exercised amounts per account to support partial cash settlement analytics.

## Similar DeFi option protocols
- **Opyn** – pioneer on Ethereum; uses oTokens and full collateral vaults ([contracts](https://github.com/opynfinance/GammaProtocol/tree/master/contracts)).
- **Hegic** – automated pool that sells ETH/WBTC calls and puts with fixed expiries ([contracts](https://github.com/hegic/contracts/tree/main/packages/v8888/contracts)).
- **Dopex** – Arbitrum vaults (SSOV) where sellers lock collateral and buyers pick strike and expiry combos ([contracts](https://github.com/code-423n4/2023-08-dopex/tree/main/contracts)).
- **Lyra** – Optimism/Arbitrum AMM with delta-hedged market makers and Chainlink pricing ([contracts](https://github.com/derivexyz/v1-core/tree/master/contracts)).
- **Premia** – multi-chain, peer-to-pool options with flexible strikes and expiries ([contracts](https://github.com/Premian-Labs/v3-contracts/tree/master/contracts)).
- **Ribbon / Aevo** – vault strategies that sell covered calls and an order-book exchange for options ([contracts](https://github.com/ribbon-finance/ribbon-v2/tree/master/contracts)).
- **PsyOptions** – Solana SPL options, offers both American and European styles ([contracts](https://github.com/mithraiclabs/psyoptions/tree/master/programs/psy_american)).
- **Zeta Markets** – Solana exchange with unified margin for options and perps ([contracts](https://github.com/zetamarkets/serum-dex/tree/master/dex/src)).
- **Synquote** – RFQ marketplace for bespoke on-chain option quotes ([contracts – org page](https://github.com/synquote)).
- **Thales** – Synthetix ecosystem binary and vanilla options settled in sUSD ([contracts](https://github.com/thales-markets/contracts/tree/main/contracts)).
- **Panoptic** – builds perpetual options on top of Uniswap V3 liquidity ([contracts](https://github.com/panoptic-labs/panoptic-v1-core/tree/v1.0.x/contracts)).
- **Friktion (legacy)** – Solana automated strategies for covered calls and cash-secured puts ([contracts – legacy tooling](https://github.com/Friktion-Labs/captain)).
