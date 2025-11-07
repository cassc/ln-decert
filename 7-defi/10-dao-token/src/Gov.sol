// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {Bank} from "./Bank.sol";

contract Gov {
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed
    }

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes callData;
        uint64 voteStart;
        uint64 voteEnd;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bytes32 descriptionHash;
        mapping(address => bool) hasVoted;
    }

    error ZeroAddress();
    error ZeroValue();
    error ThresholdNotMet(address proposer);
    error ProposalDoesNotExist(uint256 proposalId);
    error ProposalNotActive(uint256 proposalId);
    error AlreadyVoted(address voter, uint256 proposalId);
    error NoVotingPower(address voter);
    error ProposalNotSuccessful(uint256 proposalId);
    error AlreadyExecuted(uint256 proposalId);
    error CallFailed(uint256 proposalId, bytes revertData);

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed target,
        uint256 value,
        bytes callData,
        uint64 voteStart,
        uint64 voteEnd,
        string description
    );

    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);

    event ProposalExecuted(uint256 indexed proposalId, address indexed target, uint256 value, bytes callData);

    IVotes public immutable token;
    Bank public immutable bank;
    uint256 public immutable quorumVotes;
    uint256 public immutable proposalThreshold;
    uint32 public immutable votingDelay;
    uint32 public immutable votingPeriod;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) private _proposals;

    /// @notice Deploy the governor contract and configure voting parameters.
    /// @param token_ ERC20Votes token used for voting power snapshots.
    /// @param bank_ Bank that will execute withdrawals approved by governance.
    /// @param quorumVotes_ Minimum for-vote weight required to pass.
    /// @param proposalThreshold_ Minimum voting power needed to create a proposal.
    /// @param votingDelay_ Blocks to wait before voting starts.
    /// @param votingPeriod_ Blocks the vote stays open.
    constructor(
        IVotes token_,
        Bank bank_,
        uint256 quorumVotes_,
        uint256 proposalThreshold_,
        uint32 votingDelay_,
        uint32 votingPeriod_
    ) {
        if (address(token_) == address(0) || address(bank_) == address(0)) {
            revert ZeroAddress();
        }
        if (quorumVotes_ == 0 || proposalThreshold_ == 0 || votingPeriod_ == 0) {
            revert ZeroValue();
        }
        token = token_;
        bank = bank_;
        quorumVotes = quorumVotes_;
        proposalThreshold = proposalThreshold_;
        votingDelay = votingDelay_;
        votingPeriod = votingPeriod_;
    }

    /// @notice Create a proposal that will execute an arbitrary call when passed.
    /// @param target Address that will be called during execution.
    /// @param value Native ETH value forwarded with the call.
    /// @param callData Encoded function selector + arguments.
    /// @param description Human readable text describing the proposal.
    /// @return proposalId Sequential identifier for the newly created proposal.
    function propose(address target, uint256 value, bytes calldata callData, string calldata description)
        external
        returns (uint256)
    {
        if (target == address(0)) {
            revert ZeroAddress();
        }
        if (token.getVotes(msg.sender) < proposalThreshold) {
            revert ThresholdNotMet(msg.sender);
        }

        uint256 proposalId = ++proposalCount;
        uint64 start = uint64(block.number + votingDelay);
        uint64 end = start + votingPeriod;

        Proposal storage proposal = _proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.target = target;
        proposal.value = value;
        proposal.callData = callData;
        proposal.voteStart = start;
        proposal.voteEnd = end;
        proposal.descriptionHash = keccak256(bytes(description));

        emit ProposalCreated(proposalId, msg.sender, target, value, callData, start, end, description);
        return proposalId;
    }

    /// @notice Cast a vote on an active proposal using past voting power.
    /// @param proposalId Identifier returned by `propose`.
    /// @param support True to vote for, false to vote against.
    /// @return weight Amount of votes counted for the chosen side.
    function castVote(uint256 proposalId, bool support) external returns (uint256 weight) {
        Proposal storage proposal = _loadProposal(proposalId);
        ProposalState currentState = state(proposalId);
        if (currentState != ProposalState.Active) {
            revert ProposalNotActive(proposalId);
        }
        if (proposal.hasVoted[msg.sender]) {
            revert AlreadyVoted(msg.sender, proposalId);
        }
        weight = token.getPastVotes(msg.sender, proposal.voteStart);
        if (weight == 0) {
            revert NoVotingPower(msg.sender);
        }

        proposal.hasVoted[msg.sender] = true;
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    /// @notice Execute a successful proposal and trigger its call.
    /// @param proposalId Identifier of the proposal to execute.
    function execute(uint256 proposalId) external {
        Proposal storage proposal = _loadProposal(proposalId);
        if (proposal.executed) {
            revert AlreadyExecuted(proposalId);
        }
        ProposalState currentState = state(proposalId);
        if (currentState != ProposalState.Succeeded) {
            revert ProposalNotSuccessful(proposalId);
        }

        proposal.executed = true;
        (bool success, bytes memory returndata) =
            proposal.target.call{value: proposal.value}(proposal.callData);
        if (!success) {
            revert CallFailed(proposalId, returndata);
        }

        emit ProposalExecuted(proposalId, proposal.target, proposal.value, proposal.callData);
    }

    /// @notice Read detailed information for a proposal.
    /// @param proposalId Identifier to query.
    /// @return proposer Address that created the proposal.
    /// @return target Address the proposal will call.
    /// @return value ETH value forwarded.
    /// @return callData Encoded calldata for the call.
    /// @return voteStart Block when voting can begin.
    /// @return voteEnd Block when voting ends.
    /// @return forVotes Total weight that supported the proposal.
    /// @return againstVotes Total weight that opposed the proposal.
    /// @return executed True if the proposal has already executed.
    /// @return descriptionHash Hash of the human readable description.
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            address target,
            uint256 value,
            bytes memory callData,
            uint64 voteStart,
            uint64 voteEnd,
            uint256 forVotes,
            uint256 againstVotes,
            bool executed,
            bytes32 descriptionHash
        )
    {
        Proposal storage proposal = _loadProposal(proposalId);
        return (
            proposal.proposer,
            proposal.target,
            proposal.value,
            proposal.callData,
            proposal.voteStart,
            proposal.voteEnd,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.descriptionHash
        );
    }

    /// @notice Return the current lifecycle state for a proposal.
    /// @param proposalId Identifier to inspect.
    /// @return ProposalState enum describing the status.
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = _loadProposal(proposalId);

        if (proposal.executed) {
            return ProposalState.Executed;
        }
        if (block.number <= proposal.voteStart) {
            return ProposalState.Pending;
        }
        if (block.number <= proposal.voteEnd) {
            return ProposalState.Active;
        }
        if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        }
        return ProposalState.Succeeded;
    }

    /// @dev Fetch a proposal or revert if it is not found.
    /// @param proposalId Identifier to lookup.
    /// @return proposal Storage pointer to the proposal struct.
    function _loadProposal(uint256 proposalId) private view returns (Proposal storage proposal) {
        proposal = _proposals[proposalId];
        if (proposal.voteStart == 0) {
            revert ProposalDoesNotExist(proposalId);
        }
    }
}
