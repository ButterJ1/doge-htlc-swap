// // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23

import { Immutables } from "../libraries/ImmutablesLib.sol";

interface IEscrow {
    event Withdrawn(address indexed to, bytes32 secret);
    event Cancelled(address indexed to);

    error InvalidSecret();
    error TimelockNotReached();
    error TimelockExpired();
    error OnlyResolver();
    error OnlyMaker();
    error InsufficientSafetyDeposit();
    error TokenTranferFailed();

    function withdraw(bytes32 secret) external;
    function cancel() external;

    function rescueFunds(address token_) external;
}