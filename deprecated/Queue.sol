// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Queue {
    struct UnstakeRequest {
        uint256 pendingAmount;
        uint256 fulfilledAmount;
        bool isPaidOut;
    }

    struct UnstakeQueue {
        UnstakeRequest[] req;
        uint256 front;
        uint256 rear;
    }

    function length() public {}

    // @function push:
    function push() internal {}

    // @function pop:
    function pop() internal {}
}
