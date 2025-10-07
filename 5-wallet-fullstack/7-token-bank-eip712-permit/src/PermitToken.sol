// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice ERC20 token with EIP-2612 permit support used across the TokenBank and NFT market flows.
contract PermitToken is ERC20, ERC20Permit, Ownable {
    /// @notice Creates the token, assigning the initial supply and ownership to `initialOwner`.
    constructor(address initialOwner)
        ERC20("Permit Token", "PTKN")
        ERC20Permit("Permit Token")
        Ownable(initialOwner)
    {
        _mint(initialOwner, 1_000_000 ether);
    }

    /// @notice Simple owner-only minting hook to simplify test setup and demos.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
