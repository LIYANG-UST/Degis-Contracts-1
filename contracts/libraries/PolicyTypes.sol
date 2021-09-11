// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Policy {
    enum PolicyStatus {
        INI,
        SOLD,
        DECLINED,
        EXPIRED,
        CLAIMED
    }

    struct policyInfo {
        uint256 productId;
        address buyerAddress;
        uint256 totalOrder;
        bytes32 policyId;
        uint256 premium;
        uint256 payoff;
        uint256 purchaseDate;
        uint256 departureDate;
        PolicyStatus status; // 0: INI, 1: SOLD, 2: DECLINED, 3: EXPIRED, 4: CLAIMED
        // Oracle Related
        bool isUsed; // Whether has called the oracle
        uint256 delayResult; // [400:cancelled] [0: on time] [0 ~ 240: delay time] [404: initial]
    }
}
