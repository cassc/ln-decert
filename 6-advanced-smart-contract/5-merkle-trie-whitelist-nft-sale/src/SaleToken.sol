// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract SaleToken is ERC20, ERC20Permit, Ownable {
    constructor()
        ERC20("Whitelist Purchase Token", "WPT")
        ERC20Permit("Whitelist Purchase Token")
        Ownable(msg.sender)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
