// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract RebaseToken is IERC20, IERC20Metadata {
    string private constant _NAME = "Deflationary Rebase Token";
    string private constant _SYMBOL = "DRT";
    uint8 private constant _DECIMALS = 18;

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    uint256 private constant YEAR = 365 days;

    uint256 private constant RATE_NUMERATOR = 99;
    uint256 private constant RATE_DENOMINATOR = 100;

    uint256 private constant MAX_UINT256 = type(uint256).max;
    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_SUPPLY);

    address public owner;
    uint256 public lastRebaseTimestamp;
    uint256 public rebaseCount;

    uint256 private _totalSupply = INITIAL_SUPPLY;
    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Ratio between internal gons and user units; balanceOf(account) returns _gonBalances[account] / _gonsPerFragment
    uint256 private _gonsPerFragment = TOTAL_GONS / INITIAL_SUPPLY;

    event Rebase(uint256 indexed epoch, uint256 newTotalSupply);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "RebaseToken: caller is not owner");
        _;
    }

    constructor(address initialRecipient) {
        require(initialRecipient != address(0), "RebaseToken: zero recipient");
        owner = msg.sender;
        lastRebaseTimestamp = block.timestamp;
        _gonBalances[initialRecipient] = TOTAL_GONS;
        emit Transfer(address(0), initialRecipient, INITIAL_SUPPLY);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function name() external pure override returns (string memory) {
        return _NAME;
    }

    function symbol() external pure override returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external pure override returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _gonBalances[account] / _gonsPerFragment;
    }

    function allowance(address holder, address spender) public view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "RebaseToken: insufficient allowance");
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "RebaseToken: allowance below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "RebaseToken: zero owner");
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    function rebase() external onlyOwner returns (uint256) {
        require(block.timestamp >= lastRebaseTimestamp + YEAR, "RebaseToken: rebase too soon");
        lastRebaseTimestamp = block.timestamp;
        rebaseCount += 1;

        _totalSupply = (_totalSupply * RATE_NUMERATOR) / RATE_DENOMINATOR;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        emit Rebase(rebaseCount, _totalSupply);
        return _totalSupply;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "RebaseToken: transfer from zero");
        require(to != address(0), "RebaseToken: transfer to zero");
        require(amount > 0, "RebaseToken: amount zero");

        uint256 gonValue = amount * _gonsPerFragment;
        require(_gonBalances[from] >= gonValue, "RebaseToken: balance too low");

        unchecked {
            _gonBalances[from] -= gonValue;
            _gonBalances[to] += gonValue;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "RebaseToken: approve from zero");
        require(spender != address(0), "RebaseToken: approve to zero");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
}
