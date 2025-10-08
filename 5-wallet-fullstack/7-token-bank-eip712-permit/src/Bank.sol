// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PermitToken} from "./PermitToken.sol";

/// @notice Token-based bank that supports EIP-2612 permit powered deposits.
contract Bank {
    PermitToken public immutable token;
    address public immutable admin;

    mapping(address => uint256) public balances;
    address[3] private topDepositors;

    event Deposit(address indexed account, uint256 amount);
    event UserWithdraw(address indexed account, uint256 amount);
    event AdminWithdraw(address indexed to, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Bank: caller is not admin");
        _;
    }

    constructor(PermitToken token_) {
        require(address(token_) != address(0), "Bank: invalid token");
        token = token_;
        admin = msg.sender;
    }

    /// @notice Deposit tokens that have already been approved for the Bank.
    function deposit(uint256 amount) external {
        _pullAndRecord(msg.sender, amount);
    }

    /// @notice Deposit tokens using an EIP-2612 permit signature instead of a prior approval.
    function permitDeposit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(owner != address(0), "Bank: invalid owner");
        token.permit(owner, address(this), amount, deadline, v, r, s);
        _pullAndRecord(owner, amount);
    }

    /// @notice Withdraw deposited tokens back to the caller.
    function withdraw(uint256 amount) external {
        require(amount > 0, "Bank: zero withdraw");
        uint256 balance = balances[msg.sender];
        require(balance >= amount, "Bank: insufficient balance");

        balances[msg.sender] = balance - amount;
        _updateTopDepositors(msg.sender);

        bool transferred = token.transfer(msg.sender, amount);
        require(transferred, "Bank: transfer failed");

        emit UserWithdraw(msg.sender, amount);
    }

    /// @notice Admin hook to move surplus tokens to a predefined address.
    function adminWithdraw(address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "Bank: invalid recipient");
        require(amount <= token.balanceOf(address(this)), "Bank: insufficient funds");
        bool transferred = token.transfer(to, amount);
        require(transferred, "Bank: transfer failed");
        emit AdminWithdraw(to, amount);
    }

    function getTopDepositors() external view returns (address[3] memory) {
        return topDepositors;
    }

    function _pullAndRecord(address owner, uint256 amount) private {
        require(amount > 0, "Bank: zero deposit");
        bool success = token.transferFrom(owner, address(this), amount);
        require(success, "Bank: transfer failed");
        balances[owner] += amount;
        emit Deposit(owner, amount);
        _updateTopDepositors(owner);
    }

    function _updateTopDepositors(address account) private {
        uint256 accountBalance = balances[account];
        bool placed = false;

        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (topDepositors[i] == account) {
                placed = true;
                break;
            }
        }

        if (!placed) {
            for (uint256 i = 0; i < topDepositors.length; i++) {
                if (topDepositors[i] == address(0)) {
                    topDepositors[i] = account;
                    placed = true;
                    break;
                }
            }
        }

        if (!placed) {
            uint256 lowestIndex = 0;
            uint256 lowestBalance = balances[topDepositors[0]];

            for (uint256 i = 1; i < topDepositors.length; i++) {
                uint256 candidateBalance = balances[topDepositors[i]];
                if (candidateBalance < lowestBalance) {
                    lowestBalance = candidateBalance;
                    lowestIndex = i;
                }
            }

            if (accountBalance > lowestBalance) {
                topDepositors[lowestIndex] = account;
            }
        }

        for (uint256 i = 0; i < topDepositors.length; i++) {
            for (uint256 j = i + 1; j < topDepositors.length; j++) {
                address left = topDepositors[i];
                address right = topDepositors[j];

                if (balances[right] > balances[left]) {
                    (topDepositors[i], topDepositors[j]) = (right, left);
                }
            }
        }
    }
}
