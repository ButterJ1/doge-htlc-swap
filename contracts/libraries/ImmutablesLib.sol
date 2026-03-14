// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23

import { Timelocks } from "./TimelocksLib.sol";

struct Immutables {
    // The keccak256 preimage that unlocks the escrow.
    // The secret is the raw bytes32 whose keccak256 equals this value.
    bytes32 hashlock;

    // Token that is locked inside this escrow (address(0) = native).
    address token;

    // Who deposited the tokens (maker = user on src, resolver on dst).
    address maker;
    
    // Who receives the tokens upon successful withdrawal.
    address taker;

    // Amoount of tokens locked.
    uint256 amount;

    // Safety deposit in native tokens (wei / DOGE-wei on DogeChain).
    uint256 safetyDeposit;

    // Packed timelock durations. See TimelocksLib.
    Timelocks timelocks;
}

library ImmutablesLib {
    function hash(Immutables memmory immutables) internal pure returns (bytes32) {
        return keccak256(abi.encode(immutables));
    }
}