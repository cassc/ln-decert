## BuggyToken Example

This Foundry workspace demonstrates a deliberately vulnerable ERC20-style token. The `BuggyToken` contract in `src/BuggyToken.sol` allows anyone to seize ownership because `setOwner` lacks access control. The invariant test in `test/BuggyTokenInvariant.t.sol` targets the contract directly and randomizes callers, exposing the flaw by breaking the expectation that the deployer stays owner.

### Run the invariant suite

```sh
forge test --match-test invariant_onlyDeployerRemainsOwner
```

The run fails, confirming that non-authorized addresses can wrest control of the token.

## Tooling

Foundry provides the build, test, and scripting toolchain used in this example. See the [Foundry book](https://book.getfoundry.sh/) for reference commands.
