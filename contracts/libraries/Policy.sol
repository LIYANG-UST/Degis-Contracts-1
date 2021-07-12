// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Policy {
    struct policy {
        uint256 productId;
        address buyerAddress;
        bytes32 policyId;
        uint256 premium;
        uint256 payoff;
        uint256 expiryDate;
        bool isClaimed;
    }

    constructor() {}

    function getPolicyProductId(policy calldata _policy)
        public
        pure
        returns (uint256)
    {
        return _policy.productId;
    }

    function getPolicyBuyer(policy calldata _policy)
        public
        pure
        returns (address)
    {
        return _policy.buyerAddress;
    }

    function getPolicyId(policy calldata _policy)
        public
        pure
        returns (bytes32)
    {
        return _policy.policyId;
    }

    function getPolicyExpiryDate(policy calldata _policy)
        public
        pure
        returns (uint256)
    {
        return _policy.expiryDate;
    }
}
