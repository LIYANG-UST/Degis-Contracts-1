// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Policy {
    struct policy {
        fixed probability;
        uint256 payoffAmount;
    }

    constructor() {}

    function getPolicyPayoff(policy calldata _policy)
        public
        pure
        returns (uint256 _payoff)
    {
        return _policy.payoffAmount;
    }
}
