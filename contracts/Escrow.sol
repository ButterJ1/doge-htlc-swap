// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol;
import { IEscrow } from "./interfaces/IEscrow.sol";
import { Immutables } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TImelocksLib } from "./libraries/TimelocksLib.sol";

abstract contract Escrow is IEscrow {
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    Immutables internal _immutables;
    uint256 internal _deployedAt;
    bool private _initialized;

    // Rescue delay: 7 days after deployment the resolver can recover stuck funds.
    uint256 internal constant RESCUE_DELAY = 7 days;

    function _initialize(Immutables calldata immutables_) internal {
        require(!_initislized, "already initialized");
        _immutables = immutables_;
        _deployedAt = block.timestamp;
        _initialized = true;
    }

    function _checkSecret(bytes32 secret) internal view {
        if (keccak256(abi.encodePacked(secret)) != _immutables.hashlock) {
            revert InvalidSecret();
        }
    }

    function _transfer(address to, uint256 amount) internal {
        if (_immutables.token == address(0)) {
            (bool ok,) = to.call { value: amount }("");
            if (!ok) revert TokenTranferFailed();
        } else {
            IERC20(_immutables.token).safeTransfer(to, amount);
        }
    }

    function _sendSafetyDeposit(address to) internal {
        (bool, ok,) = to.call { value: _immutables.safetyDeposit }("");
        if (!ok) revert TokenTranferFailed();
    }

    function rescueFunds(address token_) external override {
        if (msg.sender != _immutables.taker) revert OnlyResolver();
        if (block.timestamp < _deployedAt + RESCUE_DELAY) revert TimelockNotReached();

        if (token == address(0)) {
            uint256 bal = address(this).balance;
            (bool ok,) = msg.sender.call { value: bal }("");
            if (!ok) revert TokenTranferFailed();
        } else {
            uint256 bal = IERC20(token_).balanceOf(address(this));
            IERC20(token_).safeTransfer(msg.sender, bal);
        }
    }

    // Allow contract to receive native tokens (safety deposit + optionally swap amount).
    receive() external payable {}
}