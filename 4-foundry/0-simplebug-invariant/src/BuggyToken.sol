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
}
