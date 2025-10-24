# Token Vesting (Foundry)

This project is a Foundry workspace for the ERC20 vesting contract.

## Contract Rules
- One beneficiary per contract instance.
- Contract funds itself with 1,000,000 whole tokens in the constructor.
- Cliff is 12 months from the deploy block timestamp.
- Vesting unlocks linearly over the next 24 months (30-day months).
- Anyone may call `release()` after the cliff.
- `release()` reverts before the cliff and sends only the unlocked balance.

## Project Layout
- `src/TokenVesting.sol` contains the contract code.
- `test/TokenVesting.t.sol` contains unit tests with a mock ERC20 and a fuzz test.

## Setup
```shell
forge install
```

## Run Tests
```shell
forge test
```

Fuzz runs default to 256; override with `forge test --fuzz-runs <N>` if you want more samples.

## Build
```shell
forge build
```

## Notes
- Deploy a new instance for each beneficiary you support.
- Update the constructor amount if you need a different grant size.
