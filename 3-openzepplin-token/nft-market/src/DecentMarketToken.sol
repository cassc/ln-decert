// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC777Recipient} from "@openzeppelin/contracts/interfaces/IERC777Recipient.sol";

/// @notice Simple ERC20 token with an extra transfer function that passes data to receiver contracts.
contract DecentMarketToken is ERC20, Ownable {
    event TokensSent(address indexed operator, address indexed from, address indexed to, uint256 amount, bytes data);

    constructor(string memory name_, string memory symbol_, address owner_) ERC20(name_, symbol_) Ownable(owner_) {}

    /// @notice Mint new tokens.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Transfer tokens with attached data so receivers can react through tokensReceived.
    function transferWithData(address to, uint256 amount, bytes calldata data) external returns (bool) {
        _transfer(msg.sender, to, amount);
        _notifyTokensReceived(msg.sender, msg.sender, to, amount, data);
        emit TokensSent(msg.sender, msg.sender, to, amount, data);
        return true;
    }

    /// @notice Transfer tokens on behalf of another account with attached data.
    function transferFromWithData(address from, address to, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        _notifyTokensReceived(msg.sender, from, to, amount, data);
        emit TokensSent(msg.sender, from, to, amount, data);
        return true;
    }

    function _notifyTokensReceived(address operator, address from, address to, uint256 amount, bytes calldata data)
        private
    {
        if (to.code.length == 0) {
            return;
        }

        try IERC777Recipient(to).tokensReceived(operator, from, to, amount, data, "") {
            return;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("Receiver rejected tokens");
            }
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }
    }
}
