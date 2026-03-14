// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Escrow } from "./Escrow.sol";
import { Immutables } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

contract EscrowSrc is Escrow {
    using TimelocksLib for Timelocks;

    function initialize(Immutables calldata immutables_) external payable {
        if (msg.value < immutables_.safetyDeposit) revert InsufficientSafetyDeposit();
        _initialize(immutables_);
    }

    function withdraw(bytes32 secret) external override {
        uint256 ts = block.timestamp;
        uint256 deployedAt = _deployedAt;

        uint256 withdrawalStart = _immutables.timelocks.srcWithdrawalStart(deployedAt);
        uint256 cancellationStart = _immutables.timelocks.srcCancellationStart(deployedAt);

        if (ts < withdrawalStart) revert TimelockNotReached();
        if (ts >= cancellationStart) revert TimelockExpired();

        uint256 publicWithdrawalStart = _immutables.timelocks.srcPublicWithdrawalStart(deployedAt);
        if (ts < publicWithdrawalStart && msg.sender != _immutables.taker) {
            revert OnlyResolver();
        }

        _checkSecret(secret);

        address recipient = _immutables.taker;
        uint256 amount = _immutables.amount;

        emit Withdrawn(recipient, secret);

        _transfer(recipient, amount);
        _sendSafetyDeposit(msg.sender);
    }

    function cancel() external override {
        uint256 ts = block.timestamp;
        uint256 deployAt = _deployedAt;

        uint256 cancellationStart = _immutables.timelocks.srcCancellationStart(deployAt);
        if (ts < cancellationStart) revert TimelockNotReached();

        uint256 publicCancellationStart = _immutables.timelocks.srcPublicCancellationStart(deployAt);
        if (ts < publicCancellationStart && msg.sender != _immutables.taker) {
            revert OnlyResolver();
        }

        address maker = _immutables.maker;
        uint256 amount = _immutables.amount;

        emit Cancelled(maker);

        _transfer(maker, amount);
        _sendSafetyDeposit(msg.sender);
    }
}