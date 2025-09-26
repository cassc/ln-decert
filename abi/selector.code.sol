pragma solidity ^0.8.0;

contract FunctionSelector {
    uint256 private storedValue;

    function getValue() public view returns (uint) {
        return storedValue;
    }

    function setValue(uint value) public {
        storedValue = value;
    }

    function getFunctionSelector1() public pure returns (bytes4) {
        return this.getValue.selector;
    }

    function getFunctionSelector2() public pure returns (bytes4) {
        return this.setValue.selector;
    }
}
