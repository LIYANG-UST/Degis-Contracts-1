// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interface/IPolicyFlow.sol";

contract PolicyFlow {
    constructor() {}

    function newApplication() public returns (uint256) {}

    function policySold() external returns (uint256) {}

    function policyDeclined() external {}

    function policyExpired() external {}

    function policyClaimed() external {}
}
