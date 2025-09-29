// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BuggyToken
/// @notice ERC20-like token with an intentional access control bug for demo purposes.
contract BuggyToken {
    string public constant name = "BuggyToken";
    string public constant symbol = "BUG";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    address public owner;

    uint128 public constant PROMO_MAX_CLAIM = 1_000 ether;

    struct StagedMint {
        uint128 amount;
        uint128 unlockCode;
    }

    mapping(address => StagedMint) private stagedMints;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "BuggyToken: not owner");
        _;
    }

    /// @notice Intentionally missing an access control check; anyone can take over ownership.
    function setOwner(address newOwner) external {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "BuggyToken: mint to zero");

        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "BuggyToken: transfer to zero");

        uint256 senderBalance = balanceOf[msg.sender];
        require(senderBalance >= amount, "BuggyToken: insufficient balance");

        unchecked {
            balanceOf[msg.sender] = senderBalance - amount;
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Queue a promotional mint that should require a deliberate second step to execute.
    function stagePromotionalMint(address recipient, uint128 amount, uint128 unlockCode) external onlyOwner {
        require(recipient != address(0), "BuggyToken: promo to zero");
        require(amount > 0, "BuggyToken: promo amount zero");
        require(amount <= PROMO_MAX_CLAIM, "BuggyToken: promo cap exceeded");

        stagedMints[recipient] = StagedMint(amount, unlockCode);
    }

    /// @notice Execute the staged promotional mint.
    /// @dev BUG: The staged entry is never cleared, allowing repeated mints with the same code.
    function executePromotionalMint(uint128 providedCode) external {
        StagedMint memory staged = stagedMints[msg.sender];
        require(staged.amount > 0, "BuggyToken: no staged promo");
        require(staged.unlockCode == providedCode, "BuggyToken: invalid promo code");

        totalSupply += staged.amount;
        balanceOf[msg.sender] += staged.amount;
        emit Transfer(address(0), msg.sender, staged.amount);
    }

    function getStagedMint(address account) external view returns (uint128 amount, uint128 unlockCode) {
        StagedMint memory staged = stagedMints[account];
        return (staged.amount, staged.unlockCode);
    }
}
