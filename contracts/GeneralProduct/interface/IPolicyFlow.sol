// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPolicyFlow {
    event newPolicyApplication();
    event newPolicySold();

    event PolicyDeclined();
    event PolicyClaimed();
    event PolicyExpired();

    function newApplication() external;

    function policySold() external;

    function policyDeclined() external;
}
