// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPolicyTypes {
    /// @notice Enum type of the policy status
    enum PolicyStatus {
        INI,
        SOLD,
        DECLINED,
        EXPIRED,
        CLAIMED
    }

    /// @notice Policy information struct
    struct PolicyInfo {
        uint256 productId; // 0: flight delay 1,2,3: future products
        address buyerAddress; // buyer's address
        uint256 policyId; // total order: 0 - N (unique for each policy)(used to link)
        string flightNumber; // Flight number
        uint256 premium; // Premium
        uint256 payoff; // Max payoff
        uint256 purchaseDate; // Unix timestamp (s)
        uint256 departureDate; // Used for buying new applications. Unix timestamp (s)
        uint256 landingDate; // Used for oracle. Unix timestamp (s)
        PolicyStatus status; // INI, SOLD, DECLINED, EXPIRED, CLAIMED
        // Oracle Related
        bool isUsed; // Whether has call the oracle
        uint256 delayResult; // [400:cancelled] [0: on time] [0 ~ 240: delay time] [404: initial]
    }

    struct PolicyTokenURIParam {
        uint256 productId;
        string flightNumber;
        uint256 policyId;
        address owner;
        uint256 premium;
        uint256 payoff;
        uint256 purchaseDate;
        uint256 departureDate;
        uint256 landingDate;
        uint256 status;
    }
}
