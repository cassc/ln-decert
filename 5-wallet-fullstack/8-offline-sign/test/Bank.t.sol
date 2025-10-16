// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract MockWETH {
    string public constant name = "Mock Wrapped Ether";
    string public constant symbol = "mWETH";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "MockWETH: insufficient balance");
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "MockWETH: insufficient allowance");
        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "MockWETH: invalid recipient");
        require(balanceOf[from] >= amount, "MockWETH: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

interface IERC20Like {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract Permit2Mock is ISignatureTransfer {
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address token,uint256 amount,address to,uint256 requestedAmount,uint256 nonce,uint256 deadline)"
        );

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external override {
        require(block.timestamp <= permit.deadline, "Permit2Mock: expired");
        require(transferDetails.requestedAmount <= permit.permitted.amount, "Permit2Mock: too much requested");
        bytes32 digest = _hashPermit(permit, transferDetails, owner);
        _verifySignature(owner, digest, signature);
        bool success = IERC20Like(permit.permitted.token).transferFrom(
            owner,
            transferDetails.to,
            transferDetails.requestedAmount
        );
        require(success, "Permit2Mock: transfer failed");
    }

    function hashPermit(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner
    ) external pure returns (bytes32) {
        return _hashPermit(permit, transferDetails, owner);
    }

    function _hashPermit(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    owner,
                    permit.permitted.token,
                    permit.permitted.amount,
                    transferDetails.to,
                    transferDetails.requestedAmount,
                    permit.nonce,
                    permit.deadline
                )
            );
    }

    function _verifySignature(
        address owner,
        bytes32 digest,
        bytes memory signature
    ) internal pure {
        require(signature.length == 65, "Permit2Mock: invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "Permit2Mock: invalid signature v");
        address signer = ecrecover(digest, v, r, s);
        require(signer == owner, "Permit2Mock: invalid signature");
    }
}

contract BankTest is Test {
    Bank internal bank;
    MockWETH internal weth;
    Permit2Mock internal permit2;
    address internal alice;
    uint256 internal aliceKey;
    address internal bob;
    address internal carol;
    address internal dave;

    function setUp() public {
        (alice, aliceKey) = makeAddrAndKey("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        dave = makeAddr("dave");

        weth = new MockWETH();
        bank = new Bank(address(weth));
        permit2 = new Permit2Mock();
        vm.etch(address(bank.PERMIT2()), address(permit2).code);
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

    function testDepositWithPermit2() public {
        uint256 amount = 1 ether;
        vm.deal(alice, amount);

        vm.prank(alice);
        weth.deposit{value: amount}();
        assertEq(weth.balanceOf(alice), amount);

        address permit2Address = address(bank.PERMIT2());
        vm.prank(alice);
        weth.approve(permit2Address, amount);

        ISignatureTransfer.TokenPermissions memory permissions = ISignatureTransfer.TokenPermissions({
            token: address(weth),
            amount: amount
        });
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: permissions,
            nonce: 0,
            deadline: block.timestamp + 1
        });
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(bank),
            requestedAmount: amount
        });

        bytes memory signature = _signPermit(aliceKey, permit, transferDetails, alice);

        vm.prank(alice);
        bank.depositWithPermit2(permit, transferDetails, alice, signature);

        assertEq(weth.balanceOf(address(bank)), 0);
        assertEq(bank.balances(alice), amount);
        assertEq(address(bank).balance, amount);
    }

    function testDepositWithPermit2ViaRelayer() public {
        uint256 amount = 1 ether;
        vm.deal(alice, amount);

        vm.prank(alice);
        weth.deposit{value: amount}();

        address permit2Address = address(bank.PERMIT2());
        vm.prank(alice);
        weth.approve(permit2Address, amount);

        ISignatureTransfer.TokenPermissions memory permissions = ISignatureTransfer.TokenPermissions({
            token: address(weth),
            amount: amount
        });
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: permissions,
            nonce: 1,
            deadline: block.timestamp + 100
        });
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(bank),
            requestedAmount: amount
        });

        bytes memory signature = _signPermit(aliceKey, permit, transferDetails, alice);

        vm.prank(bob);
        bank.depositWithPermit2(permit, transferDetails, alice, signature);

        assertEq(bank.balances(alice), amount);
        assertEq(bank.balances(bob), 0);
        assertEq(address(bank).balance, amount);
    }

    function testDepositWithPermit2ExpiredReverts() public {
        uint256 amount = 1 ether;
        vm.deal(alice, amount);

        vm.prank(alice);
        weth.deposit{value: amount}();

        address permit2Address = address(bank.PERMIT2());
        vm.prank(alice);
        weth.approve(permit2Address, amount);

        ISignatureTransfer.TokenPermissions memory permissions = ISignatureTransfer.TokenPermissions({
            token: address(weth),
            amount: amount
        });
        uint256 deadline = block.timestamp;
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: permissions,
            nonce: 0,
            deadline: deadline
        });
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(bank),
            requestedAmount: amount
        });

        bytes memory signature = _signPermit(aliceKey, permit, transferDetails, alice);

        vm.warp(deadline + 1);

        vm.startPrank(alice);
        vm.expectRevert("Permit2Mock: expired");
        bank.depositWithPermit2(permit, transferDetails, alice, signature);
        vm.stopPrank();
    }

    function _signPermit(
        uint256 key,
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        address owner
    ) private view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encode(
                permit2.PERMIT_TYPEHASH(),
                owner,
                permit.permitted.token,
                permit.permitted.amount,
                transferDetails.to,
                transferDetails.requestedAmount,
                permit.nonce,
                permit.deadline
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _deposit(address user, uint256 amount) private {
        vm.deal(user, amount);
        vm.prank(user);
        bank.deposit{value: amount}();
    }
}
