// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Simple ERC20 token used for demos and local testing.
contract PermitToken is ERC20, Ownable {
    constructor(address initialOwner) ERC20("Permit Token", "PTKN") Ownable(initialOwner) {
        _mint(initialOwner, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
