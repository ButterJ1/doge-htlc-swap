// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { IEscrow } from "../contracts/interfaces/IEscrow.sol";
import { Immutables } from "../contracts/libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract EscrowPhase1Test is Test {
    using TimelocksLib for Timelocks;

    EscrowFactory factory;
    MockERC20 token;

    address maker = address(0xA1);
    address resolver = address(0xB2);
    address attacker = address(0xC3);

    uint64 constant DST_WITHDRAWAL = 1 minutes;
    uint64 constant DST_PUBLIC_WITHDRAWAL = 2 minutes;
    uint64 constant DST_CANCELLATION = 10 minutes;
    uint64 constant DST_PUBLIC_CANCELLATION = 15 minutes;

    uint64 constant SRC_WITHDRAWAL = 3 minutes;
    uint64 constant SRC_PUBLIC_WITHDRAWAL = 5 minutes;
    uint64 constant SRC_CANCELLATION = 20 minutes;
    uint64 constant SRC_PUBLIC_CANCELLATION = 30 minutes;

    uint256 constant SWAP_AMOUNT = 100 ether;
    uint256 constant SAFETY_DEPOSIT = 0.01 ether;

    bytes32 secret;
    bytes32 hashlock;

    function setUp() public {
        factory = new EscrowFactory();
        token = new MockERC20();

        secret = keccak256("test-secret-do-not-use-in-production");
        hashlock = keccak256(abi.encodePacked(secret));

        deal(address(token), maker, SWAP_AMOUNT * 10);
        deal(address(token), resolver, SWAP_AMOUNT * 10);
        deal(maker, 10 ether);
        deal(resolver, 10 ether);
    }

    function _buildSrcImmutables() internal view returns (Immutables memory) {
        return Immutables({
            hashlock: hashlock,
            token: address(token),
            maker: maker,
            taker: resolver,
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: TimelocksLib.build(
                SRC_WITHDRAWAL,
                SRC_PUBLIC_WITHDRAWAL,
                SRC_CANCELLATION,
                SRC_PUBLIC_CANCELLATION
            )
        });
    }

    function _buildDstImmutables() internal view returns (Immutables memory) {
        return Immutables({
            hashlock: hashlock,
            token: address(token),
            maker: maker,
            taker: resolver,
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: TimelocksLib.build(
                DST_WITHDRAWAL,
                DST_PUBLIC_WITHDRAWAL,
                DST_CANCELLATION,
                DST_PUBLIC_CANCELLATION
            )
        });
    }

    function _deploySrcEscrow() internal returns (address escrow, Immutables memory imm) {
        imm = _buildSrcImmutables();

        vm.startPrank(maker);
        token.approve(address(factory), SWAP_AMOUNT);
        escrow = factory.createSrcEscrow{value: SAFETY_DEPOSIT}(imm);
        vm.stopPrank();
    }

    function _deployDstEscrow() internal returns (address escrow, Immutables memory imm) {
        imm = _buildDstImmutables();

        vm.startPrank(resolver);
        token.approve(address(factory), SWAP_AMOUNT);
        escrow = factory.createDstEscrow{value: SAFETY_DEPOSIT}(imm);
        vm.stopPrank();
    }

    function test_addressPrediction_src() public {
        Immutables memory imm = _buildSrcImmutables();
        address predicted = factory.addressOfEscrowSrc(imm);

        vm.startPrank(maker);
        token.approve(address(factory), SWAP_AMOUNT);
        address deployed = factory.createSrcEscrow{value: SAFETY_DEPOSIT}(imm);
        vm.stopPrank();

        assertEq(predicted, deployed, "src address prediction mismatch");
    }

    function test_addressPrediction_dst() public {
        Immutables memory imm = _buildDstImmutables();
        address predicted = factory.addressOfEscrowDst(imm);

        vm.startPrank(resolver);
        token.approve(address(factory), SWAP_AMOUNT);
        address deployed = factory.createDstEscrow{value: SAFETY_DEPOSIT}(imm);
        vm.stopPrank();

        assertEq(predicted, deployed, "dst address prediction mismatch");
    }

    function test_happyPath_fullSwap() public {
        (address srcEscrow,) = _deploySrcEscrow();
        (address dstEscrow,) = _deployDstEscrow();

        uint256 makerBalBefore = token.balanceOf(maker);
        uint256 resolverBalBefore = token.balanceOf(resolver);

        skip(DST_WITHDRAWAL + 1);

        vm.prank(maker);
        EscrowDst(payable(dstEscrow)).withdraw(secret);
        assertEq(
            token.balanceOf(maker),
            makerBalBefore + SWAP_AMOUNT,
            "maker did not receive dst tokens"
        );

        skip(SRC_WITHDRAWAL - DST_WITHDRAWAL);

        vm.prank(resolver);
        EscrowSrc(payable(srcEscrow)).withdraw(secret);

        assertEq(
            token.balanceOf(resolver),
            resolverBalBefore + SWAP_AMOUNT,
            "resolver did not receive src tokens"
        );
    }

    function test_revert_wrongSecret_src() public {
        (address srcEscrow,) = _deploySrcEscrow();
        skip(SRC_WITHDRAWAL + 1);

        bytes32 wrongSecret = keccak256("wrong-secret");

        vm.prank(resolver);
        vm.expectRevert(IEscrow.InvalidSecret.selector);
        EscrowSrc(payable(srcEscrow)).withdraw(wrongSecret);
    }

    function test_revert_wrongSecret_dst() public {
        (address dstEscrow,) = _deployDstEscrow();
        skip(DST_WITHDRAWAL + 1);

        bytes32 wrongSecret = keccak256("wrong-secret");

        vm.prank(maker);
        vm.expectRevert(IEscrow.InvalidSecret.selector);
        EscrowDst(payable(dstEscrow)).withdraw(wrongSecret);
    }

    function test_revert_withdrawTooEarly_src() public {
        (address srcEscrow,) = _deploySrcEscrow();

        vm.prank(resolver);
        vm.expectRevert(IEscrow.TimelockNotReached.selector);
        EscrowSrc(payable(srcEscrow)).withdraw(secret);
    }

    function test_revert_withdrawTooEarly_dst() public {
        (address dstEscrow,) = _deployDstEscrow();

        vm.prank(maker);
        vm.expectRevert(IEscrow.TimelockNotReached.selector);
        EscrowDst(payable(dstEscrow)).withdraw(secret);
    }

    function test_revert_attackerCannotWithdraw_srcPrivateWindow() public {
        (address srcEscrow,) = _deploySrcEscrow();
        skip(SRC_WITHDRAWAL + 1);

        vm.prank(attacker);
        vm.expectRevert(IEscrow.OnlyResolver.selector);
        EscrowSrc(payable(srcEscrow)).withdraw(secret);
    }

    function test_publicWithdraw_dst_anyoneCanFinalize() public {
        (address dstEscrow,) = _deployDstEscrow();
        skip(DST_PUBLIC_WITHDRAWAL + 1);

        uint256 makerBalBefore = token.balanceOf(maker);

        vm.prank(attacker);
        EscrowDst(payable(dstEscrow)).publicWithdraw(secret);

        assertEq(
            token.balanceOf(maker),
            makerBalBefore + SWAP_AMOUNT,
            "maker did not receive tokens via public withdrawal"
        );
    }

    function test_cancel_src_resolverGetsRefund() public {
        (address srcEscrow,) = _deploySrcEscrow();
        skip(SRC_CANCELLATION + 1);

        uint256 makerBalBefore = token.balanceOf(maker);

        vm.prank(resolver);
        EscrowSrc(payable(srcEscrow)).cancel();

        assertEq(
            token.balanceOf(maker),
            makerBalBefore + SWAP_AMOUNT,
            "maker did not get refund"
        );
    }

    function test_revert_cancelTooEarly_src() public {
        (address srcEscrow,) = _deploySrcEscrow();

        vm.prank(resolver);
        vm.expectRevert(IEscrow.TimelockNotReached.selector);
        EscrowSrc(payable(srcEscrow)).cancel();
    }

    function test_revert_withdrawAfterCancellationStart_src() public {
        (address srcEscrow,) = _deploySrcEscrow();
        skip(SRC_CANCELLATION + 1);

        vm.prank(resolver);
        vm.expectRevert(IEscrow.TimelockExpired.selector);
        EscrowSrc(payable(srcEscrow)).withdraw(secret);
    }

    function test_revert_insufficientSafetyDeposit() public {
        Immutables memory imm = _buildSrcImmutables();

        vm.startPrank(maker);
        token.approve(address(factory), SWAP_AMOUNT);
        vm.expectRevert(EscrowFactory.InsufficientNativeAmount.selector);
        factory.createSrcEscrow{value: SAFETY_DEPOSIT - 1}(imm);
        vm.stopPrank();
    }

    function test_escrowHoldsTokens_afterDeployment() public {
        (address srcEscrow,) = _deploySrcEscrow();

        assertEq(
            token.balanceOf(srcEscrow),
            SWAP_AMOUNT,
            "escrow does not hold the correct token amount"
        );
        assertEq(
            srcEscrow.balance,
            SAFETY_DEPOSIT,
            "escrow does not hold the correct safety deposit"
        );
    }

    function test_revert_rescueTooEarly() public {
        (address srcEscrow,) = _deploySrcEscrow();
        skip(6 days);

        vm.prank(resolver);
        vm.expectRevert(IEscrow.TimelockNotReached.selector);
        EscrowSrc(payable(srcEscrow)).rescueFunds(address(token));
    }

    function test_rescue_worksAfterDelay() public {
        (address srcEscrow,) = _deploySrcEscrow();
        skip(7 days + 1);

        uint256 balBefore = token.balanceOf(resolver);

        vm.prank(resolver);
        EscrowSrc(payable(srcEscrow)).rescueFunds(address(token));

        assertGt(
            token.balanceOf(resolver),
            balBefore,
            "resolver did not recover tokens"
        );
    }
}