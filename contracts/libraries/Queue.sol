// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Queue {

    struct UnstakeRequest {
        uint256 pendingAmount;
        uint256 fulfilledAmount;
        bool isPaidOut;
    }
}