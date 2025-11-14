// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "permit2/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

/// @notice Token Bank that supports classic ERC20 transfers plus Permit2 signature-based deposits.
contract Bank {
    IERC20 public immutable token;
    IPermit2 public immutable permit2;
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

    constructor(IERC20 token_, IPermit2 permit2_) {
        require(address(token_) != address(0), "Bank: invalid token");
        require(address(permit2_) != address(0), "Bank: invalid permit2");
        token = token_;
        permit2 = permit2_;
        admin = msg.sender;
    }

    /// @notice Deposit tokens that have already approved the Bank to spend them.
    function deposit(uint256 amount) external {
        _pullFromAndRecord(msg.sender, amount);
    }

    /// @notice Deposit tokens using a Permit2 signature instead of a prior approval.
    function depositWithPermit2(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        require(owner != address(0), "Bank: invalid owner");
        require(permit.permitted.token == address(token), "Bank: invalid token");
        require(transferDetails.to == address(this), "Bank: invalid recipient");
        require(transferDetails.requestedAmount > 0, "Bank: zero deposit");

        permit2.permitTransferFrom(permit, transferDetails, owner, signature);
        _recordDeposit(owner, transferDetails.requestedAmount);
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

    /// @notice Admin hook that lets the contract owner rescue excess tokens.
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

    function _pullFromAndRecord(address owner, uint256 amount) private {
        require(amount > 0, "Bank: zero deposit");
        bool success = token.transferFrom(owner, address(this), amount);
        require(success, "Bank: transfer failed");
        _recordDeposit(owner, amount);
    }

    function _recordDeposit(address account, uint256 amount) private {
        balances[account] += amount;
        emit Deposit(account, amount);
        _updateTopDepositors(account);
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
