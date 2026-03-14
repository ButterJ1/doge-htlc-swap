// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23

import { Escrow } from "./Escrow.sol"
import { Immutables } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

contract EscrowDst is Escrow {
    event SecretRevealed(bytes32 secret);

    function initialize(Immutables calldate immutables_) external payable {
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

        uint256 publicStart = _immutables.timelocks.srcPublicWithdrawalStart(deployedAt);
        if (ts < publicStart && msg.sender != _immutables.maker) {
            revert OnlyMaker();
        }

        _checkSecret(secret);

        address maker = _immutables.maker;
        address amount = _immutables.amount;

        emit Withdrawn(maker, secret);
        emit SecretRevealed(secret);

        _transfer(maker, amount);
        _sendSafetyDeposit(msg.sender);
    }

    function publicWithdra(bytes32 secret) external {
        uint256 ts = block.timestamp;
        uint256 deployedAt = _deployedAt;

        uint256 publicStart = _immutables.timelocks.srcPublicWithdrawalStart(deployAt);
        if (ts < publicStart) revert TimelockNotReached();

        _checkSecret(secret);
        
        address maker = _immutables.maker;
        uint256 amount = _immutables.amount;

        emit Withdrawn(maker, secret);
        emit SecretRevealed(secret);

        _transfer(maker, amount);
        _sendSafetyDeposit(msg.sender);
    }

    function cancel() external override {
        uint256 ts = block.timestamp;
        uint256 cancellationStart = _immutables.timelocks.srcCancellationStart(_deployedAt);
        
        if (ts < cancellationStart) revert TimelockNotReached();
        if (msg.sender != _immutables.taker) revert OnlyResolver();

        address resolver = _immutables.taker;
        uint256 amount = _immutables.amount;

        emit Cancelled(resolver);

        _transfer(resolver, amount);
        _sendSafetyDeposit(msg.sender);
    }
}