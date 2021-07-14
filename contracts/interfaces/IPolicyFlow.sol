// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPolicyFlow {
    event newPolicyApplication(bytes32 _policyID, address);
    event newPolicySold(bytes32 _policyID, address);
    event PolicyDeclined(bytes32 _policyID, address);
    event PolicyClaimed(bytes32 _policyID, address);
    event PolicyExpired(bytes32 _policyID, address);

    function newApplication() external returns (uint256);

    function policySold() external;

    function policyDeclined() external;
}
