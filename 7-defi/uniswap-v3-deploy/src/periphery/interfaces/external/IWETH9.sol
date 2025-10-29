// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title WETH9 接口
interface IWETH9 is IERC20 {
    /// @notice 存入以太币以获得包裹的以太币
    function deposit() external payable;

    /// @notice 取出包裹的以太币以获得以太币
    function withdraw(uint256) external;
}
