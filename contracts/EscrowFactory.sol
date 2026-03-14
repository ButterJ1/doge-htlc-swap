// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { EscrowDst } from "./EscrowDst.sol";
import { Immutables, ImmutablesLib } from "./libraries/ImmutablesLib.sol";

contract EscrowFactory {
    using SafeERC20 for IERC20;
    using ImmutablesLib for Immutables;

    address public immutable escrowSrcImpl;
    address public immutable escrowDstImpl;

    event SrcEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed maker,
        address taker,
        address token,
        uint256 amount
    );

    event DstEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed maker,
        address taker,
        address token,
        uint256 amount
    );

    error ZeroAddress();
    error InsufficientNativeAmount();

    constructor() {
        escrowSrcImpl = address(new EscrowSrc());
        escrowDstImpl = address(new EscrowDst());
    }

    function addressOfEscrowSrc(Immutables calldata immutables_) external view returns (address) {
        return Clones.predictDeterministicAddress(escrowSrcImpl, immutables_.hash(), address(this));
    }

    function addressOfEscrowDst(Immutables calldata immutables_) external view returns (address) {
        return Clones.predictDeterministicAddress(escrowDstImpl, immutables_.hash(), address(this));
    }

    function createSrcEscrow(Immutables calldata immutables_) external payable returns (address escrow) {
        if (immutables_.maker == address(0) || immutables_.taker == address(0)) {
            revert ZeroAddress();
        }

        if (immutables_.token == address(0)) {
            if (msg.value < immutables_.amount + immutables_.safetyDeposit) revert InsufficientNativeAmount();
        } else {
            if (msg.value < immutables_.safetyDeposit) revert InsufficientNativeAmount();

            address predicted = Clones.predictDeterministicAddress(escrowSrcImpl, immutables_.hash(), address(this));
            IERC20(immutables_.token).safeTransferFrom(immutables_.maker, predicted, immutables_.amount);
        }

        escrow = Clones.cloneDeterministic(escrowSrcImpl, immutables_.hash());
        EscrowSrc(payable(escrow)).initialize{ value: msg.value }(immutables_);

        emit SrcEscrowCreated(
            escrow,
            immutables_.hashlock,
            immutables_.maker,
            immutables_.taker,
            immutables_.token,
            immutables_.amount
        );
    }

    function createDstEscrow(Immutables calldata immutables_) external payable returns (address escrow) {
        if (immutables_.maker == address(0) || immutables_.taker == address(0)) {
            revert ZeroAddress();
        }

        if (immutables_.token == address(0)) {
            if (msg.value < immutables_.amount + immutables_.safetyDeposit) {
                revert InsufficientNativeAmount();
            }
        } else {
            if (msg.value < immutables_.safetyDeposit) revert InsufficientNativeAmount();

            address predicted = Clones.predictDeterministicAddress(escrowDstImpl, immutables_.hash(), address(this));
            IERC20(immutables_.token).safeTransferFrom(immutables_.taker, predicted, immutables_.amount);
        }

        escrow = Clones.cloneDeterministic(escrowDstImpl, immutables_.hash());
        EscrowDst(payable(escrow)).initialize{ value: msg.value }(immutables_);

        emit DstEscrowCreated(
            escrow,
            immutables_.hashlock,
            immutables_.maker,
            immutables_.taker,
            immutables_.token,
            immutables_.amount
        );
    }
}