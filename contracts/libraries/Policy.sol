// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Policy {
    struct policyInfo {
        uint256 productId;
        address buyerAddress;
        bytes32 policyId;
        uint256 premium;
        uint256 payoff;
        uint256 expiryDate;
        bool isClaimed;
    }

    constructor() {}

    function getPolicyProductId(policyInfo calldata _policy)
        public
        pure
        returns (uint256)
    {
        return _policy.productId;
    }

    function getPolicyBuyer(policyInfo calldata _policy)
        public
        pure
        returns (address)
    {
        return _policy.buyerAddress;
    }

    function getPolicyId(policyInfo calldata _policy)
        public
        pure
        returns (bytes32)
    {
        return _policy.policyId;
    }

    function getPolicyExpiryDate(policyInfo calldata _policy)
        public
        pure
        returns (uint256)
    {
        return _policy.expiryDate;
    }
}
