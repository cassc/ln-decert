// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract Bank {
    error NotAdmin(address caller);
    error InvalidAdmin();
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed();

    address public admin;

    event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) {
            revert InvalidAdmin();
        }
        admin = initialAdmin;
        emit AdminUpdated(address(0), initialAdmin);
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin(msg.sender);
        }
        _;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert InvalidAdmin();
        }
        emit AdminUpdated(admin, newAdmin);
        admin = newAdmin;
    }

    function withdraw(address payable to, uint256 amount) external onlyAdmin {
        uint256 balance = address(this).balance;
        if (amount > balance) {
            revert InsufficientBalance(amount, balance);
        }
        (bool ok,) = to.call{value: amount}("");
        if (!ok) {
            revert TransferFailed();
        }
        emit Withdraw(to, amount);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
