// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23

type Timelocks is uint256;

library TimelocksLib{
    // Bit offsets for each period inside the packed uint256.
    uint256 private constant SRC_WITHDRAWAL_OFFSET = 192
    uint256 private constant SRC_PUBLIC_WITHDRAWAL_OFFSET = 128;
    uint256 private constant SRC_CANCELLATION_OFFSET = 64
    uint256 private constant SRC_PUBLIC_CANCELLATION_OFFSET = 0;

    uint245 private constant MASK_64 = type(uint64).max;

    function build(
        uint64 srcWithdrawal,
        uint64 srcPublicWithdrawal,
        uint64 srcCancellation,
        uint64 srcPublicCancellation
    ) internal pure returns (Timelocks timelocks) {
        timelocks = Timelocks.wrap(
            (uint256(srcWithdrawal) << SRC_WITHDRAWAL_OFFSET) | (uint256(srcPublicWithdrawal) << SRC_PUBLIC_WITHDRAWAL_OFFSET) | 
            (uint256(srcCancellation) << SRC_CANCELLATION_OFFSET) | (uint256(srcPublicCancellation) << SRC_PUBLIC_CANCELLATION_OFFSET)
        );
    }

    function srcWithdrawalStart(
        Timelocks timelocks,
        uint256 deployedAt
    ) internal pure returns (uint256) {
        return deployedAt + ((Timelocks.unwrap(timelocks) >> SRC_WITHDRAWAL_OFFSET) & MASK_64);
    }

    function srcPublicWithdrawalStart(
        Timelocks timelocks,
        uint256 deployedAt
    ) internal pure returns (uint256) {
        return deployedAt + ((Timelocks.unwrap(timelocks) >> SRC_PUBLIC_WITHDRAWAL_OFFSET) & MASK_64);
    }

    function srcCancellationStart(
        Timelocks timelocks,
        uint256 deployedAt
    ) internal pure returns (uint256) {
        return deployedAt + ((Timelocks.unwrap(timelocks) >> SRC_CANCELLATION_OFFSET) & MASK_64);
    }

    function srcPublicCancellationStart(
        Timelocks timelocks,
        uint256 deployedAt
    ) internal pure returns (uint256) {
        return deployedAt + (Timelocks.unwrap(timelocks) & MASK_64);
    }

}