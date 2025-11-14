// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";
import {PermitToken} from "../src/PermitToken.sol";
import {Permit2} from "permit2/Permit2.sol";
import {IPermit2} from "permit2/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

contract BankTest is Test {
    bytes32 private constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 private constant PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)"
            "TokenPermissions(address token,uint256 amount)"
        );

    Bank internal bank;
    PermitToken internal token;
    Permit2 internal permit2;

    uint256 internal aliceKey = 0xA11CE;
    uint256 internal bobKey = 0xB0B;
    uint256 internal carolKey = 0xCA401;
    uint256 internal daveKey = 0xDA1E;

    address internal alice = vm.addr(aliceKey);
    address internal bob = vm.addr(bobKey);
    address internal carol = vm.addr(carolKey);
    address internal dave = vm.addr(daveKey);

    function setUp() public {
        token = new PermitToken(address(this));
        permit2 = new Permit2();
        bank = new Bank(token, IPermit2(address(permit2)));

        token.mint(alice, 10 ether);
        token.mint(bob, 10 ether);
        token.mint(carol, 10 ether);
        token.mint(dave, 10 ether);
    }

    function testDepositUpdatesUserBalance() public {
        _directDeposit(alice, 1 ether);
        assertEq(bank.balances(alice), 1 ether);
    }

    function testPermit2DepositUpdatesBalance() public {
        uint256 amount = 2 ether;
        _permitDeposit(aliceKey, alice, amount, 1, block.timestamp + 1 days);
        assertEq(bank.balances(alice), amount);
    }

    function testTopDepositorsWithVaryingUsersAndRepeatDeposits() public {
        _directDeposit(alice, 1 ether);
        address[3] memory top = bank.getTopDepositors();
        assertEq(top[0], alice);
        assertEq(top[1], address(0));
        assertEq(top[2], address(0));

        _directDeposit(bob, 2 ether);
        top = bank.getTopDepositors();
        assertEq(top[0], bob);
        assertEq(top[1], alice);
        assertEq(top[2], address(0));

        _permitDeposit(carolKey, carol, 3 ether, 1, block.timestamp + 1 days);
        top = bank.getTopDepositors();
        assertEq(top[0], carol);
        assertEq(top[1], bob);
        assertEq(top[2], alice);

        _directDeposit(dave, 4 ether);
        top = bank.getTopDepositors();
        assertEq(top[0], dave);
        assertEq(top[1], carol);
        assertEq(top[2], bob);

        _permitDeposit(aliceKey, alice, 5 ether, 2, block.timestamp + 1 days);
        top = bank.getTopDepositors();
        assertEq(top[0], alice);
        assertEq(top[1], dave);
        assertEq(top[2], carol);
    }

    function testAdminWithdrawOnlyAdminCanCall() public {
        _directDeposit(alice, 5 ether);
        address admin = bank.admin();
        address receiver = makeAddr("receiver");

        vm.prank(bob);
        vm.expectRevert("Bank: caller is not admin");
        bank.adminWithdraw(receiver, 1 ether);

        uint256 receiverBefore = token.balanceOf(receiver);
        vm.prank(admin);
        bank.adminWithdraw(receiver, 2 ether);

        assertEq(token.balanceOf(receiver), receiverBefore + 2 ether);
    }

    function testUserCanWithdrawOwnBalance() public {
        _directDeposit(alice, 4 ether);

        vm.prank(alice);
        bank.withdraw(1.5 ether);

        assertEq(bank.balances(alice), 2.5 ether);
        assertEq(token.balanceOf(alice), 7.5 ether);
    }

    function testUserWithdrawMoreThanBalanceFails() public {
        _directDeposit(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert("Bank: insufficient balance");
        bank.withdraw(2 ether);
    }

    function testDepositWithPermit2ChecksRecipient() public {
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token), amount: 1 ether}),
            nonce: 1,
            deadline: block.timestamp + 1 days
        });
        ISignatureTransfer.SignatureTransferDetails memory details = ISignatureTransfer.SignatureTransferDetails({
            to: address(0xdead),
            requestedAmount: 1 ether
        });
        bytes memory sig = bytes("mock");

        vm.expectRevert("Bank: invalid recipient");
        bank.depositWithPermit2(permit, details, alice, sig);
    }

    function _directDeposit(address user, uint256 amount) private {
        vm.prank(user);
        token.approve(address(bank), amount);

        vm.prank(user);
        bank.deposit(amount);
    }

    function _permitDeposit(
        uint256 ownerKey,
        address owner,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) private {
        vm.prank(owner);
        token.approve(address(permit2), type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token), amount: amount}),
            nonce: nonce,
            deadline: deadline
        });

        ISignatureTransfer.SignatureTransferDetails memory details = ISignatureTransfer.SignatureTransferDetails({
            to: address(bank),
            requestedAmount: amount
        });

        bytes32 permitHash = _hashPermitTransferFrom(permit);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), permitHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(owner);
        bank.depositWithPermit2(permit, details, owner, signature);
    }

    function _hashPermitTransferFrom(ISignatureTransfer.PermitTransferFrom memory permit)
        private
        view
        returns (bytes32)
    {
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
        );
        return keccak256(
            abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, address(bank), permit.nonce, permit.deadline)
        );
    }
}
