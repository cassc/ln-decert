// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyWallet {
    // Storage layout:
    // slot 0: name (string — dynamic; data elsewhere, but slot still reserved)
    // slot 1: approved (mapping — data elsewhere, but slot still reserved)
    // slot 2: owner (address — stored directly in this slot)
    string public name;
    mapping(address => bool) private approved;
    address public owner; // kept for ABI/readability; reads/writes use assembly below

    // Constant for the exact storage slot of `owner`
    uint256 private constant OWNER_SLOT = 2;


    modifier auth() {
        // Inline assembly GET of owner
        address o;
        assembly {
            o := sload(OWNER_SLOT)
        }
        require(msg.sender == o, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        // Inline assembly SET of owner
        assembly {
            sstore(OWNER_SLOT, caller())
        }
    }

    function _getOwner() internal view returns (address o) {
        assembly {
            o := sload(OWNER_SLOT)
        }
    }

    function _setOwner(address o) internal {
        assembly {
            sstore(OWNER_SLOT, o)
        }
    }

    function transferOwnership(address _addr) external auth {
        address current = _getOwner();
        require(_addr != address(0), "New owner is the zero address");
        require(_addr != current, "New owner is the same as the old owner");
        _setOwner(_addr);
    }
}
