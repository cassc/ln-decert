// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PermitToken.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    PermitToken internal token;
    Bank internal bank;

    address internal alice;
    uint256 internal aliceKey;

    address internal bob;
    address internal carol;
    address internal dave;

    function setUp() public {
        token = new PermitToken(address(this));
        bank = new Bank(token);

        (alice, aliceKey) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        dave = makeAddr("dave");

        token.transfer(alice, 10 ether);
        token.transfer(bob, 10 ether);
        token.transfer(carol, 10 ether);
        token.transfer(dave, 10 ether);
    }

    // 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
    function testDepositUpdatesUserBalance() public {
        uint256 amount = 1 ether;
        assertEq(bank.balances(alice), 0);

        _deposit(alice, amount);

        assertEq(bank.balances(alice), amount);
        assertEq(token.balanceOf(address(bank)), amount);
    }

    function testPermitDepositTransfersTokenAndUpdatesBalance() public {
        uint256 amount = 2 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(alice);
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(
            abi.encode(permitTypehash, alice, address(bank), amount, nonce, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, digest);

        vm.prank(alice);
        bank.permitDeposit(alice, amount, deadline, v, r, s);

        assertEq(bank.balances(alice), amount);
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(token.allowance(alice, address(bank)), 0);
    }

    // 检查存款金额的前 3 名用户是否正确，分别检查有1个、2个、3个、4 个用户， 以及同一个用户多次存款的情况。
    function testTopDepositorsWithVaryingUsersAndRepeatDeposits() public {
        _deposit(alice, 1 ether);
        address[3] memory top = bank.getTopDepositors();
        assertEq(top[0], alice);
        assertEq(top[1], address(0));
        assertEq(top[2], address(0));

        _deposit(bob, 2 ether);
        top = bank.getTopDepositors();
        assertEq(top[0], bob);
        assertEq(top[1], alice);
        assertEq(top[2], address(0));

        _deposit(carol, 3 ether);
        top = bank.getTopDepositors();
        assertEq(top[0], carol);
        assertEq(top[1], bob);
        assertEq(top[2], alice);

        _deposit(dave, 4 ether);
        top = bank.getTopDepositors();
        assertEq(top[0], dave);
        assertEq(top[1], carol);
        assertEq(top[2], bob);

        _deposit(alice, 5 ether);
        top = bank.getTopDepositors();
        assertEq(top[0], alice);
        assertEq(top[1], dave);
        assertEq(top[2], carol);
    }

    // 检查只有管理员可通过 adminWithdraw 取款，其他人不可以。
    function testAdminWithdrawOnlyAdminCanCall() public {
        _deposit(alice, 1 ether);
        address admin = bank.admin();
        address receiver = makeAddr("receiver");

        vm.startPrank(bob);
        vm.expectRevert("Bank: caller is not admin");
        bank.adminWithdraw(receiver, 0.2 ether);
        vm.stopPrank();

        uint256 receiverBalanceBefore = token.balanceOf(receiver);
        uint256 bankBalanceBefore = token.balanceOf(address(bank));

        vm.prank(admin);
        bank.adminWithdraw(receiver, 0.5 ether);

        assertEq(token.balanceOf(address(bank)), bankBalanceBefore - 0.5 ether);
        assertEq(token.balanceOf(receiver), receiverBalanceBefore + 0.5 ether);
    }

    // 检查用户可以成功提取自己的存款。
    function testUserCanWithdrawOwnBalance() public {
        _deposit(alice, 1 ether);
        uint256 bankBalanceBefore = token.balanceOf(address(bank));
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        bank.withdraw(0.6 ether);

        assertEq(bank.balances(alice), 0.4 ether);
        assertEq(token.balanceOf(address(bank)), bankBalanceBefore - 0.6 ether);
        assertEq(token.balanceOf(alice), aliceBalanceBefore + 0.6 ether);
    }

    // 检查用户提取超过余额会失败。
    function testUserWithdrawMoreThanBalanceFails() public {
        _deposit(alice, 0.5 ether);

        vm.startPrank(alice);
        vm.expectRevert("Bank: insufficient balance");
        bank.withdraw(0.6 ether);
        vm.stopPrank();
    }

    function _deposit(address user, uint256 amount) private {
        vm.prank(user);
        token.approve(address(bank), amount);

        vm.prank(user);
        bank.deposit(amount);
    }
}
