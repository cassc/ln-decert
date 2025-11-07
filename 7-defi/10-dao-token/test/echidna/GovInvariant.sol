// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {DaoToken} from "../../src/DaoToken.sol";
import {Bank} from "../../src/Bank.sol";
import {Gov} from "../../src/Gov.sol";
import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";

/**
 * Echidna harness that checks critical admin invariants:
 *  - The Bank admin never drifts away from the Gov contract.
 *  - Direct withdrawals performed by any non-governance caller revert.
 *
 * Echidna calls every public function with many inputs. Invariant functions
 * must have zero arguments, so we keep mutable fuzz inputs in storage and add
 * helper setters that Echidna can call with random data before running the
 * invariant.
 */
contract GovEchidna {
    DaoToken internal token;
    Bank internal bank;
    Gov internal gov;
    // Echidna mutates this value through fuzzWithdrawAmount before invariant runs.
    uint256 internal withdrawAmount = 1;

    constructor() {
        token = new DaoToken();
        bank = new Bank(address(this));
        gov = new Gov(
            IVotes(address(token)),
            bank,
            1,
            1,
            1,
            10
        );

        bank.setAdmin(address(gov));

    }

    function echidna_admin_is_always_gov() public view returns (bool) {
        return bank.admin() == address(gov);
    }

    function echidna_non_admin_withdraw_reverts() public returns (bool) {
        uint256 amount = withdrawAmount;
        try bank.withdraw(payable(address(this)), amount) {
            return false;
        } catch {
            return true;
        }
    }

    /**
     * Echidna will fuzz this helper with random numbers. We bound and store
     * the amount so the argument-free invariant can still cover many sizes.
     */
    function fuzzWithdrawAmount(uint256 amount) public {
        withdrawAmount = boundAmount(amount);
    }

    function boundAmount(uint256 amount) private pure returns (uint256) {
        if (amount == 0) {
            amount = 1;
        }
        if (amount > 1 ether) {
            amount = (amount % 1 ether) + 1;
        }
        return amount;
    }

    receive() external payable {}
}
