// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BigBank, Admin, IBank} from "../src/BigBank.sol";

contract BigBankTest is Test {
    BigBank internal bigBank;
    Admin internal admin;
    address internal adminOwner;
    address internal user1 = address(0x1);
    address internal user2 = address(0x2);
    address internal user3 = address(0x3);

    function setUp() public {
        bigBank = new BigBank();
        adminOwner = address(0xA11CE);

        vm.deal(adminOwner, 1 ether);
        vm.prank(adminOwner);
        admin = new Admin();

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    function testTransferAdminAndWithdraw() public {
        vm.prank(user1);
        bigBank.deposit{value: 0.01 ether}();

        vm.prank(user2);
        bigBank.deposit{value: 0.015 ether}();

        vm.prank(user3);
        bigBank.deposit{value: 0.02 ether}();

        vm.prank(user3);
        vm.expectRevert(bytes("BigBank: deposit too small"));
        bigBank.deposit{value: 0.001 ether}();

        uint256 totalDeposits = 0.01 ether + 0.015 ether + 0.02 ether;

        bigBank.transferAdmin(address(admin));
        assertEq(bigBank.admin(), address(admin));

        vm.prank(user1);
        vm.expectRevert(bytes("Only owner allowed"));
        admin.adminWithdraw(IBank(address(bigBank)));

        uint256 adminBalanceBefore = address(admin).balance;
        vm.prank(adminOwner);
        admin.adminWithdraw(IBank(address(bigBank)));
        assertEq(address(admin).balance, adminBalanceBefore + totalDeposits);
        assertEq(address(bigBank).balance, 0);
    }
}
