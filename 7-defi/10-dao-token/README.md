# DAO-Controlled Bank

Token holders govern how the on-chain `Bank` uses its funds. A Foundry-native Governor contract consumes delegated voting power from the governance token, enforces proposal thresholds/quorum, and, when quorum-majority proposals pass, executes privileged `Bank.withdraw` calls to move ETH to approved recipients.

## Contracts

- `src/DaoToken.sol` – ERC20 with ERC20Permit + ERC20Votes so delegation checkpoints drive governance.
- `src/Bank.sol` – vault that exposes admin-only `withdraw` and emits deposit/withdraw events for accounting.
- `src/Gov.sol` – lightweight Governor that tracks proposals, voting delay/period, quorum, and executes arbitrary calls (e.g. `Bank.withdraw`) once quorum-majority proposals succeed.

## Development

1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation) if you have not already.
2. Install dependencies (already vendored via `forge init`, but can be refreshed with `forge install`).
3. Run `forge build` / `forge fmt` as usual during development.

Repository layout mirrors Foundry defaults (`src`, `test`, `script`, etc.), and OpenZeppelin is available under `lib/openzeppelin-contracts`.

## Testing

### Foundry unit & integration tests

```sh
forge test
```

`test/Gov.t.sol` exercises the full lifecycle: proposal creation, voting with historic vote snapshots, execution that calls arbitrary targets (the test encodes `Bank.withdraw`), and guards like proposal thresholds and admin-only withdrawals.

### Echidna property tests

Property-based fuzzing adds extra confidence that only governance can move funds. This repo ships:

- Harness: `test/echidna/GovInvariant.sol`
- Config: `echidna.yaml`

#### Installing Echidna and Slither

To install Echidna, download the binary from github release page, https://github.com/crytic/echidna/releases

Slither is required by Echidna for static analysis. Install Slither via uv:

```sh
uv tool install slither-analyzer --python 3.12 
```


#### Running Echidna

Once `echidna` is on your `PATH`, execute:

```sh
echidna test/echidna/GovInvariant.sol --contract GovEchidna
# or use the config file
echidna test/echidna/GovInvariant.sol --contract GovEchidna --config echidna.yaml
```

The harness enforces two invariants:

1. The `Bank` admin can never drift away from the `Gov` contract.
2. Any withdrawal attempt by a non-admin caller must revert, regardless of requested amount.

`GovInvariant.sol` keeps a mutable `withdrawAmount` state variable so the invariant itself can stay argument-free (a hard Echidna requirement). The helper `fuzzWithdrawAmount` receives random inputs, bounds them, and stores the value before the invariant runs. This mirrors how Echidna mutates contract storage between calls when exploring the state space.
