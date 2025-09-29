## BuggyToken Example

This Foundry workspace demonstrates a deliberately vulnerable ERC20-style token. The `BuggyToken` contract in `src/BuggyToken.sol` allows anyone to seize ownership because `setOwner` lacks access control. A second bug lives in the promotional mint helper: the owner can call `stagePromotionalMint(recipient, amount, unlockCode)` once, and the recipient can keep calling `executePromotionalMint(unlockCode)` to mint fresh tokens because the stage is never cleared. The invariant test in `test/BuggyTokenInvariant.t.sol` targets the contract directly and randomizes callers, exposing the flaw by breaking the expectation that the deployer stays owner.

### Run the invariant suite

```sh
forge test --match-test invariant_onlyDeployerRemainsOwner
```

The run fails, confirming that non-authorized addresses can wrest control of the token.
