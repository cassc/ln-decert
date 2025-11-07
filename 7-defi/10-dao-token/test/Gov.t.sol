// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {DaoToken} from "../src/DaoToken.sol";
import {Bank} from "../src/Bank.sol";
import {Gov} from "../src/Gov.sol";
import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";

contract GovTest is Test {
    DaoToken internal token;
    Bank internal bank;
    Gov internal gov;

    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address payable internal constant RECIPIENT = payable(address(0xCAFE));

    uint256 internal constant BANK_BALANCE = 10 ether;
    uint256 internal constant WITHDRAW_AMOUNT = 3 ether;

    function setUp() public {
        token = new DaoToken();
        bank = new Bank(address(this));
        gov = new Gov(
            IVotes(address(token)),
            bank,
            300e18, // quorum: 300 votes
            100e18, // proposal threshold: 100 votes
            1, // voting delay (blocks)
            10 // voting period (blocks)
        );

        bank.setAdmin(address(gov));

        _mintAndDelegate(ALICE, 300e18);
        _mintAndDelegate(BOB, 200e18);
        _mintAndDelegate(RECIPIENT, 50e18);

        vm.deal(address(this), BANK_BALANCE);
        (bool ok,) = address(bank).call{value: BANK_BALANCE}("");
        assertTrue(ok, "bank funding failed");
    }

    // 提案、投票、执行的测试用例
    function testProposalLifecycle() public {
        bytes memory callData =
            abi.encodeWithSelector(Bank.withdraw.selector, RECIPIENT, WITHDRAW_AMOUNT);
        vm.prank(ALICE);
        uint256 proposalId = gov.propose(
            address(bank),
            0,
            callData,
            "Fund the core contributor"
        );
        emit log_named_uint("proposal created", proposalId);

        assertEq(
            uint256(gov.state(proposalId)),
            uint256(Gov.ProposalState.Pending),
            "proposal should be pending immediately after creation"
        );

        vm.roll(block.number + gov.votingDelay() + 1);
        emit log("voting has started");

        vm.prank(ALICE);
        uint256 aliceWeight = gov.castVote(proposalId, true);
        emit log_named_uint("alice voted for", aliceWeight);
        assertEq(aliceWeight, 300e18, "alice voting weight mismatch");

        vm.prank(BOB);
        uint256 bobWeight = gov.castVote(proposalId, false);
        emit log_named_uint("bob voted against", bobWeight);
        assertEq(bobWeight, 200e18, "bob voting weight mismatch");

        (
            ,
            ,
            ,
            ,
            ,
            uint64 voteEnd,
            uint256 forVotes,
            uint256 againstVotes,
            ,
            /* descriptionHash */

        ) = gov.getProposal(proposalId);

        assertEq(forVotes, 300e18, "for votes not tracked");
        assertEq(againstVotes, 200e18, "against votes not tracked");

        vm.roll(uint256(voteEnd) + 1);
        emit log("voting period ended");

        assertEq(
            uint256(gov.state(proposalId)),
            uint256(Gov.ProposalState.Succeeded),
            "proposal should have succeeded"
        );

        uint256 bankBefore = address(bank).balance;
        uint256 recipientBefore = RECIPIENT.balance;
        emit log("executing proposal");

        gov.execute(proposalId);

        assertEq(
            address(bank).balance,
            bankBefore - WITHDRAW_AMOUNT,
            "bank balance did not decrease"
        );
        assertEq(
            RECIPIENT.balance,
            recipientBefore + WITHDRAW_AMOUNT,
            "recipient did not receive funds"
        );
        assertEq(
            uint256(gov.state(proposalId)),
            uint256(Gov.ProposalState.Executed),
            "state should be executed"
        );
        emit log("proposal executed and funds transferred");
    }

    function testOnlyGovCanWithdraw() public {
        vm.expectRevert(abi.encodeWithSelector(Bank.NotAdmin.selector, address(this)));
        bank.withdraw(RECIPIENT, 1 ether);
    }

    function testProposalThresholdEnforced() public {
        bytes memory callData =
            abi.encodeWithSelector(Bank.withdraw.selector, RECIPIENT, WITHDRAW_AMOUNT);
        vm.startPrank(RECIPIENT);
        vm.expectRevert(abi.encodeWithSelector(Gov.ThresholdNotMet.selector, RECIPIENT));
        gov.propose(address(bank), 0, callData, "Small transfer");
        vm.stopPrank();
    }

    function testProposalDefeatedWhenAgainstMajority() public {
        bytes memory callData =
            abi.encodeWithSelector(Bank.withdraw.selector, RECIPIENT, WITHDRAW_AMOUNT);
        vm.prank(ALICE);
        uint256 proposalId = gov.propose(address(bank), 0, callData, "Fund recipient");

        vm.roll(block.number + gov.votingDelay() + 1);

        vm.prank(BOB);
        gov.castVote(proposalId, false);

        (
            ,
            ,
            ,
            ,
            ,
            uint64 voteEnd,
            ,
            ,
            ,

        ) = gov.getProposal(proposalId);

        vm.roll(uint256(voteEnd) + 1);

        assertEq(
            uint256(gov.state(proposalId)),
            uint256(Gov.ProposalState.Defeated),
            "proposal should be defeated"
        );

        vm.expectRevert(abi.encodeWithSelector(Gov.ProposalNotSuccessful.selector, proposalId));
        gov.execute(proposalId);
    }

    function testExecuteRevertsWhenCallFails() public {
        uint256 overdrawAmount = BANK_BALANCE + 1 ether;
        bytes memory callData =
            abi.encodeWithSelector(Bank.withdraw.selector, RECIPIENT, overdrawAmount);
        vm.prank(ALICE);
        uint256 proposalId = gov.propose(address(bank), 0, callData, "Overdraw bank");

        vm.roll(block.number + gov.votingDelay() + 1);
        vm.prank(ALICE);
        gov.castVote(proposalId, true);

        (
            ,
            ,
            ,
            ,
            ,
            uint64 voteEnd,
            ,
            ,
            ,

        ) = gov.getProposal(proposalId);

        vm.roll(uint256(voteEnd) + 1);

        assertEq(
            uint256(gov.state(proposalId)),
            uint256(Gov.ProposalState.Succeeded),
            "proposal should have succeeded"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Gov.CallFailed.selector,
                proposalId,
                abi.encodeWithSelector(
                    Bank.InsufficientBalance.selector,
                    overdrawAmount,
                    BANK_BALANCE
                )
            )
        );
        gov.execute(proposalId);
    }

    function _mintAndDelegate(address account, uint256 amount) private {
        token.mint(account, amount);
        vm.prank(account);
        token.delegate(account);
    }
}
