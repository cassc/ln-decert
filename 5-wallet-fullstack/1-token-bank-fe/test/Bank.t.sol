// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank internal bank;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");

    function setUp() public {
        bank = new Bank();
    }

    // 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
    function testDepositUpdatesUserBalance() public {
        uint256 amount = 1 ether;
        assertEq(bank.balances(alice), 0);

        _deposit(alice, amount);

        assertEq(bank.balances(alice), amount);
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
        address payable receiver = payable(makeAddr("receiver"));

        vm.startPrank(bob);
        vm.expectRevert("Bank: caller is not admin");
        bank.adminWithdraw(receiver, 0.2 ether);
        vm.stopPrank();

        uint256 receiverBalanceBefore = receiver.balance;
        uint256 bankBalanceBefore = address(bank).balance;

        vm.prank(admin);
        bank.adminWithdraw(receiver, 0.5 ether);

        assertEq(address(bank).balance, bankBalanceBefore - 0.5 ether);
        assertEq(receiver.balance, receiverBalanceBefore + 0.5 ether);
    }

    // 检查用户可以成功提取自己的存款。
    function testUserCanWithdrawOwnBalance() public {
        _deposit(alice, 1 ether);
        uint256 bankBalanceBefore = address(bank).balance;

        vm.prank(alice);
        bank.withdraw(0.6 ether);

        assertEq(bank.balances(alice), 0.4 ether);
        assertEq(address(bank).balance, bankBalanceBefore - 0.6 ether);
        assertEq(alice.balance, 0.6 ether);
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
        vm.deal(user, amount);
        vm.prank(user);
        bank.deposit{value: amount}();
    }
}
