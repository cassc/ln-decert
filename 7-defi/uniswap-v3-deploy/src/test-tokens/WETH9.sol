// SPDX-License-Identifier: GPL-3.0
// Copyright (C) 2015, 2016, 2017 Dapphub

// 该程序是免费软件：您可以重新分发它和/或修改
// 它遵循 GNU 通用公共许可证的条款，由
// 自由软件基金会，许可证的版本 3，或
// （由您选择）任何更高版本。

// 分发此程序是希望它有用，
// 但不提供任何保证；甚至没有默示保证
// 适销性或特定用途的适用性。  请参阅
// GNU 通用公共许可证了解更多详细信息。

// 您应该已收到 GNU 通用公共许可证的副本
// 与这个程序一起。  如果没有，请参阅 <http://www.gnu.org/licenses/>。

pragma solidity =0.7.6;

/**
 * @标题WETH9
 * @notice Wrapped Ether - 将 ETH 包装为 ERC20 代币
 * @dev 1 WETH = 1 ETH，可以双向转换
 *
 * 主要功能：
 * - deposit: 存入 ETH，获得 WETH
 * - withdraw: 销毁 WETH，取回 ETH
 * - 标准 ERC20 功能：转账、授权等
 */
contract WETH9 {
    string public name     = "Wrapped Ether";
    string public symbol   = "WETH";
    uint8  public decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    fallback() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        (bool success, ) = msg.sender.call{value: wad}("");
        require(success, "Transfer failed");
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}
