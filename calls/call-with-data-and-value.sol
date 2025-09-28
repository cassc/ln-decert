// callSetValue 方法，用于设置 Callee 合约的 value 值。要求：

// 使用 call 方法调用用 Callee 的 setValue 方法，并附带 1 Ether
// 如果发送失败，抛出“call function failed”异常并回滚交易。
// 如果发送成功，则返回 true


pragma solidity ^0.8.0;

contract Callee {
    uint256 value;

    function getValue() public view returns (uint256) {
        return value;
    }

    function setValue(uint256 value_) public payable {
        require(msg.value > 0);
        value = value_;
    }
}

contract Caller {
    function callSetValue(address callee, uint256 value) public returns (bool) {
        // call setValue()
        bytes memory payload = abi.encodeWithSelector(Callee.setValue.selector, value);
        (bool success, ) = payable(callee).call{value: 1 ether}(payload);
        require(success, "call function failed");
        return success;
    }
}
