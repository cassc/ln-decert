// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

/// @title ETH staking interface for KK reward distribution
/// @dev Defines the minimal surface used by staking pool participants
interface IStaking {
    /// @notice Stake ETH and start accruing KK rewards
    /// @dev caller must send ETH along with the tx; reverts on zero amount
    function stake() external payable;

    /// @notice Withdraw previously staked ETH
    /// @param amount Amount of ETH (in wei) to unstake
    /// @dev May trigger withdrawal from an external lending provider
    function unstake(uint256 amount) external;

    /// @notice Claim pending KK token rewards
    /// @dev Mints KK tokens via the configured reward token contract
    function claim() external;

    /// @notice Query the current staked ETH balance for an account
    /// @param account Address to check
    /// @return Current staked amount (in wei)
    function balanceOf(address account) external view returns (uint256);

    /// @notice View the unclaimed KK rewards for an account
    /// @param account Address to check
    /// @return Pending KK reward amount (in wei-like decimals)
    function earned(address account) external view returns (uint256);
}

/// @title Minimal adapter interface for an external ETH lending market
/// @dev The staking pool interacts with implementations via these hooks
interface ILendingProvider {
    /// @notice Deposit supplied ETH into the external market
    /// @dev Implementations should pull `msg.value` from the pool
    function deposit() external payable;

    /// @notice Withdraw ETH back to the pool
    /// @param recipient Address that should receive the withdrawn ETH
    /// @param amount Target amount to withdraw (implementations may return less)
    /// @return The actual amount returned to the pool
    function withdraw(address recipient, uint256 amount) external returns (uint256);
}

/// @title KK Token staking pool with per-block rewards and optional lending integration
/// @notice Users can stake ETH, accrue KK token rewards, and optionally benefit from external yield
contract StakingPool is IStaking {
    uint256 private constant PRECISION = 1e18; // rewardPerToken scaling factor
    uint256 public constant REWARD_PER_BLOCK = 10 ether; // 10 KK tokens per block

    IToken public immutable rewardToken;
    address public immutable owner;

    uint256 public totalStaked; // current sum of all user stakes
    uint256 public rewardPerTokenStored; // global accumulator
    uint256 public lastUpdateBlock; // block when rewards were last updated
    address public lendingProvider; // optional external market adapter
    bool public paused; // emergency circuit breaker state

    mapping(address => uint256) private balances; // user stake balances
    mapping(address => uint256) private userRewardPerTokenPaid; // last rewardPerToken snapshot by user
    mapping(address => uint256) private rewards; // pending rewards awaiting claim

    bool private transient _reentered; // transient storage flag for reentrancy guard

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event LendingProviderUpdated(address indexed provider);
    event Paused(address indexed account);
    event Unpaused(address indexed account);

    error Unauthorized();
    error InvalidAmount();
    error InsufficientBalance();
    error WithdrawalFailed();
    error Reentrancy();
    error PausedError();
    error NotPaused();

    /// @param _rewardToken KK token contract used for minting staking rewards
    constructor(IToken _rewardToken) {
        rewardToken = _rewardToken;
        owner = msg.sender;
        lastUpdateBlock = block.number;
    }

    /// @dev Simple boolean-based reentrancy guard leveraging transient storage
    modifier nonReentrant() {
        if (_reentered) revert Reentrancy();
        _reentered = true;
        _;
        _reentered = false;
    }

    /// @dev Refresh global + account reward accounting before mutating stake state
    modifier updateReward(address account) {
        // bring the global accumulator up to date before touching user balances
        rewardPerTokenStored = _rewardPerToken();
        lastUpdateBlock = block.number;

        if (account != address(0)) {
            uint256 accrued = _pendingReward(account, rewardPerTokenStored);
            if (accrued > 0) {
                rewards[account] += accrued;
            }
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /// @dev Restrict certain admin-only flows (e.g., wiring lending adapter)
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    /// @notice Configure or swap the external lending adapter
    /// @param provider Adapter address; use zero address to disable lending integration
    function setLendingProvider(address provider) external onlyOwner {
        lendingProvider = provider;
        emit LendingProviderUpdated(provider);
    }

    /// @notice Halt staking interactions during emergencies
    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Resume staking interactions after an emergency pause
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @inheritdoc IStaking
    function stake() external payable override nonReentrant whenNotPaused updateReward(msg.sender) {
        uint256 amount = msg.value;
        if (amount == 0) revert InvalidAmount();

        totalStaked += amount; // update aggregate stake first
        balances[msg.sender] += amount; // then credit the depositor

        address provider = lendingProvider;
        if (provider != address(0)) {
            // forward stake to the external market to capture extra yield
            ILendingProvider(provider).deposit{value: amount}();
        }

        emit Staked(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function unstake(uint256 amount) external override nonReentrant whenNotPaused updateReward(msg.sender) {
        if (amount == 0) revert InvalidAmount();

        uint256 balance = balances[msg.sender];
        if (balance < amount) revert InsufficientBalance();

        balances[msg.sender] = balance - amount; // optimistic accounting before transfers
        totalStaked -= amount; // shrink the global total

        uint256 payout = amount;
        uint256 available = address(this).balance;

        if (available < payout) {
            address provider = lendingProvider;
            if (provider != address(0)) {
                // pull back funds from the lending market to satisfy the withdrawal
                uint256 deficit = payout - available;
                uint256 withdrawn = ILendingProvider(provider).withdraw(address(this), deficit);
                if (withdrawn < deficit) revert WithdrawalFailed();
            }
            available = address(this).balance;
        }

        if (available < payout) revert WithdrawalFailed();

        (bool success,) = msg.sender.call{value: payout}("");
        if (!success) revert WithdrawalFailed();

        emit Unstaked(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function claim() external override nonReentrant whenNotPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) return;

        rewards[msg.sender] = 0;
        rewardToken.mint(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    /// @inheritdoc IStaking
    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    /// @inheritdoc IStaking
    function earned(address account) external view override returns (uint256) {
        uint256 current = _rewardPerToken();
        uint256 accrued = _pendingReward(account, current);
        return rewards[account] + accrued;
    }

    /// @notice Allow the pool (and adapters) to receive ETH
    receive() external payable {}

    /// @dev Return current rewardPerToken accumulator including blocks elapsed since last update
    function _rewardPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        uint256 blocksElapsed = block.number - lastUpdateBlock;
        if (blocksElapsed == 0) {
            return rewardPerTokenStored;
        }

        uint256 reward = blocksElapsed * REWARD_PER_BLOCK; // total new rewards since last update
        return rewardPerTokenStored + (reward * PRECISION) / totalStaked;
    }

    /// @dev Compute rewards earned by `account` since last checkpoint
    function _pendingReward(address account, uint256 currentRewardPerToken) internal view returns (uint256) {
        uint256 paid = userRewardPerTokenPaid[account];
        uint256 balance = balances[account];

        if (balance == 0 || currentRewardPerToken <= paid) {
            return 0;
        }

        uint256 delta = currentRewardPerToken - paid; // user share of global growth
        return (balance * delta) / PRECISION; // scale back down to underlying token units
    }
}
