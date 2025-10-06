// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1820Registry} from "@openzeppelin/contracts/interfaces/IERC1820Registry.sol";

contract ERC1820RegistryMock is IERC1820Registry {
    address public constant REGISTRY_ADDRESS = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;

    mapping(address => address) private _managers;
    mapping(address => mapping(bytes32 => address)) private _implementers;

    function setManager(address account, address newManager) external override {
        address currentManager = getManager(account);
        require(currentManager == msg.sender, "Not manager");
        _managers[account] = newManager;
    }

    function getManager(address account) public view override returns (address) {
        address manager = _managers[account];
        return manager == address(0) ? account : manager;
    }

    function setInterfaceImplementer(address account, bytes32 interfaceHash_, address implementer) external override {
        address currentManager = getManager(account);
        require(currentManager == msg.sender, "Not manager");
        _implementers[account][interfaceHash_] = implementer;
    }

    function getInterfaceImplementer(address account, bytes32 interfaceHash_)
        external
        view
        override
        returns (address)
    {
        return _implementers[account][interfaceHash_];
    }

    function interfaceHash(string calldata interfaceName) external pure override returns (bytes32) {
        return keccak256(bytes(interfaceName));
    }

    function updateERC165Cache(address, bytes4) external pure override {}

    function implementsERC165Interface(address account, bytes4 interfaceId) external view override returns (bool) {
        if (account.code.length == 0) {
            return false;
        }
        try IERC165(account).supportsInterface(interfaceId) returns (bool result) {
            return result;
        } catch {
            return false;
        }
    }

    function implementsERC165InterfaceNoCache(address account, bytes4 interfaceId)
        external
        view
        override
        returns (bool)
    {
        return this.implementsERC165Interface(account, interfaceId);
    }
}
