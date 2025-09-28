// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC777Recipient} from "@openzeppelin/contracts/interfaces/IERC777Recipient.sol";

contract BaseERC20 {
    string public name; 
    string public symbol; 
    uint8 public decimals; 

    uint256 public totalSupply; 

    mapping (address => uint256) balances; 

    mapping (address => mapping (address => uint256)) allowances; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // write your code here
        // set name,symbol,decimals,totalSupply
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 10**8 * (10 ** decimals);
        balances[msg.sender] = totalSupply;  
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        allowances[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        // write your code here
        return allowances[_owner][_spender];
    }
    function _transfer(address from, address to, uint256 value) internal {
        require(balances[from] >= value, "ERC20: transfer amount exceeds balance");
        balances[from] -= value;
        balances[to] += value;
        emit Transfer(from, to, value);
    }
}

// DecentMarketToken inherits from BaseERC20 and adds transferWithCallback
contract DecentMarketToken is BaseERC20 {
    constructor() BaseERC20() {
        name = "DecentMarketToken";
        symbol = "DMT";
    }

    function transferWithCallback(address to, uint256 amount, bytes calldata userData) external {
        _transfer(msg.sender, to, amount);

        if (isContract(to)) {
            IERC777Recipient(to).tokensReceived(msg.sender, msg.sender, to, amount, userData, "");
        }
    }

    // Utility function to check if an address is a contract
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
