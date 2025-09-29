// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BuggyToken} from "../src/BuggyToken.sol";

contract BuggyTokenHandler {
    BuggyToken internal token;
    uint128 internal stagedCode;

    constructor(BuggyToken _token) {
        token = _token;
    }

    /// @notice Takes ownership and queues a promo mint for this handler.
    function stagePromo(uint128 amount, uint128 unlockCode) external {
        token.setOwner(address(this));

        uint128 maxClaim = token.PROMO_MAX_CLAIM();
        uint128 mintAmount = amount % (maxClaim + 1);
        if (mintAmount == 0) {
            mintAmount = 1;
        }

        token.stagePromotionalMint(address(this), mintAmount, unlockCode);
        stagedCode = unlockCode;
    }

    /// @notice Calls execute with the stored code, minting again if it stays staged.
    function executePromo() external {
        token.executePromotionalMint(stagedCode);
    }

    function stagedInfo() external view returns (uint128 amount, uint128 code) {
        return token.getStagedMint(address(this));
    }
}

contract BuggyTokenInvariant is StdInvariant {
    BuggyToken internal token;
    address internal deployer;
    BuggyTokenHandler internal handler;

    function setUp() public {
        token = new BuggyToken();
        deployer = token.owner();
        handler = new BuggyTokenHandler(token);

        // Foundry will auto-call any public/external function on this contract during invariant runs.
        targetContract(address(token));
        targetContract(address(handler));
        targetSender(address(this));
        targetSender(address(handler));
        targetSender(address(0xBEEF));
        targetSender(address(0xCAFE));
    }

    /// @notice Expected to fail because anyone can hijack ownership via setOwner.
    function invariant_onlyDeployerRemainsOwner() public view {
        require(token.owner() == deployer, "ownership should remain with deployer");
    }

    /// @notice Should fail because executePromo can be called many times after one staging.
    function invariant_promotionalMintRunsOnce() public view {
        (uint128 stagedAmount,) = token.getStagedMint(address(handler));
        if (stagedAmount > 0) {
            require(token.balanceOf(address(handler)) <= stagedAmount, "promo mint reused");
        }
    }
}
