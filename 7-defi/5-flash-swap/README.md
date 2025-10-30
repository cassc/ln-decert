## Flash Swap Arbitrage Playground

This Foundry project shows how to create two distinct Uniswap V2 pools, force a price gap, and run an arbitrage-style flash swap between them. It uses simple ERC20 tokens and minimal Uniswap-like mocks so you can deploy and test without legacy Solidity dependencies.

### Layout
- `src/MyToken.sol` – Mintable ERC20 used to seed the pools.
- `src/FlashSwapArb.sol` – Flash swap contract that borrows from PoolA, trades on PoolB, and returns funds.
- `src/interfaces/*` – ABI shims for interacting with Uniswap V2 contracts from Solidity 0.8.
- `src/mocks/MockUniswapV2Factory.sol` – Local-only factory + pair mocks so tests run without legacy Solidity.
- `src/external/UniswapV2Artifacts.sol` – Imports the genuine Uniswap V2 factory/pair (Solidity 0.5.16) so their bytecode is available.
- `test/FlashSwap.t.sol` – Demonstrates profit when PoolA and PoolB prices differ.
- `script/Deploy.s.sol` – Deploys tokens, two real Uniswap V2 factories, seeds both pools, and deploys the flash swap contract.

### Install dependencies
```shell
forge install
```

### Build
```shell
forge build
```

### Test
```shell
forge test
```

### Deploy script
Set up your wallet via Foundry CLI flags (for example `--sender`, `--ledger`, `--mnemonic`, or `--private-key`) and run:
```shell
forge script script/Deploy.s.sol:DeployTokensAndPools \
  --sig "run(address)" <deployer_wallet_address> \
  --rpc-url <rpc_url> \
  --broadcast
```
This uses `vm.getCode("UniswapV2Factory.sol:UniswapV2Factory")` to deploy two **genuine Uniswap V2 factories** (Solidity 0.5.16) and then seeds the pools with different price ratios. Run `forge build` first so the factory and pair artifacts are present in `out/`.

### Run arbitrage on-chain
The default setup aims to grow your Token B stack. We borrow Token A from the 1:1 pool, sell it in the 1:2 pool, repay the loan in Token B, and keep the leftover Token B as profit. Swap the roles if you want profit in Token A instead.

If you want to maximize Token A instead:
- Borrow Token B from the rich pool (the one where B is cheap; here that is `PairB`).
- Swap the borrowed Token B back into Token A using the other pool (`PairA`).
- Repay the flash loan in Token A and keep the remaining Token A.
Adjust the arguments so `token_borrow_address` is Token B and the pair order reflects this swap direction.

Use the helper script to call `FlashSwapArb.startArbitrage` with your deployed addresses:
```shell
forge script script/RunArbitrage.s.sol:RunArbitrage \
  --sig "run(address,address,address,address,address,uint256,address)" \
  <caller_wallet_address> \
  <flash_arb_address> \
  <pair_borrow_address> \
  <pair_swap_address> \
  <token_borrow_address> \
  <borrow_amount_wei> \
  <profit_recipient_address> \
  --rpc-url <rpc_url> \
  --broadcast
```
Arguments:
- `caller_wallet_address`: the EOA that owns `FlashSwapArb` (same deployer used in `Deploy.s.sol`).
- `flash_arb_address`: address logged as `FlashSwapArb` when you ran the deploy script.
- `pair_borrow_address`: pool you borrow from. Example: `PairA` has 1 A : 1 B after deploy, so borrow there.
- `pair_swap_address`: pool you trade on. Example: `PairB` has 1 A : 2 B, so swap there to capture profit.
- `token_borrow_address`: token you plan to borrow (e.g. `TokenA (MTA)` address).
- `borrow_amount_wei`: amount to borrow expressed in wei (use `ether` helper when pasting, e.g. `100 ether` → `100000...`).
- `profit_recipient_address`: wallet that should receive the profit; often the same as `caller_wallet_address`.

Tip: copy addresses straight from the deploy-script logs or from the broadcast JSON file in `broadcast/Deploy.s.sol/`.

### Arbitrage logic
- Pool A starts 1 Token A : 1 Token B.
- Pool B starts 1 Token A : 2 Token B.
- Borrow the token that is more valuable in Pool B, trade it there, repay the loan, keep the difference.
- The flash swap guarantees the borrow and repay happen inside one transaction, so no upfront capital is needed.

### Foundry docs
<https://book.getfoundry.sh/>
