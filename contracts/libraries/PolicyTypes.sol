// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PolicyTypes {
    enum PolicyStatus {
        INI,
        SOLD,
        DECLINED,
        EXPIRED,
        CLAIMED
    }

    struct PolicyInfo {
        uint256 productId; // 0: flight delay 1,2,3: future products
        address buyerAddress; // buyer's address
        uint256 totalOrder; // total order: 0 - N (unique for each policy)(used to link)
        string flightNumber;
        bytes32 policyId; // unique ID (bytes32) for this policy
        uint256 premium;
        uint256 payoff;
        uint256 purchaseDate; // Unix timestamp
        uint256 departureDate; // Unix timestamp
        uint256 landingDate;
        PolicyStatus status; // INI, SOLD, DECLINED, EXPIRED, CLAIMED
        // Oracle Related
        bool isUsed; // Whether has call the oracle
        uint256 delayResult; // [400:cancelled] [0: on time] [0 ~ 240: delay time] [404: initial]
    }

    // Events list
    event newPolicyApplication(bytes32 _policyID, address indexed _userAddress);
    event PolicySold(bytes32 _policyID, address indexed _userAddress);
    event PolicyDeclined(bytes32 _policyID, address indexed _userAddress);
    event PolicyClaimed(bytes32 _policyID, address indexed _userAddress);
    event PolicyExpired(bytes32 _policyID, address indexed _userAddress);
    event FulfilledOracleRequest(bytes32 _policyId, bytes32 _requestId);
    event PolicyOwnerTransfer(uint256 indexed _tokenId, address _newOwner);
}
