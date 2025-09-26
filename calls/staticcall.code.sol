pragma solidity ^0.8.0;

contract Callee {
    function getData() public pure returns (uint256) {
        return 42;
    }
}

contract Caller {
    function callGetData(address callee) public view returns (uint256 data) {
        // call by staticcall
        bytes memory payload = abi.encode(Callee.getData.selector);
        (bool success, bytes memory respData) = callee.staticcall(payload);
        require(success, "staticcall function failed");
        (data) = abi.decode(respData, (uint256));
        return data;
    }
}
