// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    using SafeERC20 for IERC20;

    uint256 private constant MONTH_SECONDS = 30 days;
    uint256 private constant CLIFF_DURATION = 12 * MONTH_SECONDS;
    uint256 private constant VESTING_MONTHS = 24;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable totalAllocation;
    uint256 public immutable startTimestamp;
    uint256 public immutable cliffTimestamp;
    uint256 public immutable vestingEndTimestamp;

    uint256 public released;

    event TokensReleased(uint256 amount);

    constructor(IERC20 token_, address beneficiary_, uint256 totalAmount) {
        require(address(token_) != address(0), "token zero");
        require(beneficiary_ != address(0), "beneficiary zero");
        require(totalAmount > 0, "amount zero");

        token = token_;
        beneficiary = beneficiary_;
        totalAllocation = totalAmount;

        uint256 start = block.timestamp;
        startTimestamp = start;
        cliffTimestamp = start + CLIFF_DURATION;
        vestingEndTimestamp = cliffTimestamp + VESTING_MONTHS * MONTH_SECONDS;

        token_.safeTransferFrom(msg.sender, address(this), totalAmount);
    }

    function release() external {
        require(block.timestamp >= cliffTimestamp, "cliff not reached");

        uint256 vested = vestedAmount(block.timestamp);
        uint256 payableAmount = vested - released;
        require(payableAmount > 0, "nothing to release");

        released += payableAmount;
        token.safeTransfer(beneficiary, payableAmount);

        emit TokensReleased(payableAmount);
    }

    function releasable() external view returns (uint256) {
        if (block.timestamp < cliffTimestamp) {
            return 0;
        }

        uint256 vested = vestedAmount(block.timestamp);
        return vested - released;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < cliffTimestamp) {
            return 0;
        }

        if (timestamp >= vestingEndTimestamp) {
            return totalAllocation;
        }

        uint256 monthsElapsed = (timestamp - cliffTimestamp) / MONTH_SECONDS;
        if (monthsElapsed > VESTING_MONTHS) {
            monthsElapsed = VESTING_MONTHS;
        }

        return (totalAllocation * monthsElapsed) / VESTING_MONTHS;
    }
}
