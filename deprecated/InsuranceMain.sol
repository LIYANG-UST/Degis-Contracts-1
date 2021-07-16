// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InsurancePool.sol";

contract InsuranceMain {
    struct PolicyInfo {
        uint256 payoff;
        uint256 expiryTime;
        address holder;
    }

    InsurancePool pool_contract;

    address public owner;

    mapping(address => mapping(uint256 => PolicyInfo)) userPolicyInfo;
    mapping(address => uint256) userPolicyIndex;

    constructor(address _pool_addr) {
        owner = msg.sender;
        pool_contract = InsurancePool(_pool_addr);
    }

    function buyInsurance() public pure returns (bool) {
        // calcPremium();

        // checkWhenBuy();
        // updateWhenBuy();

        //updateUserInfo();
        //updateInsurancePool();

        // policy = _buildInsurance();
        // index = userPolicyIndex[user_add];
        // userPolicyInfo[user_add][index + 1] = policy;
        // userPolicyIndex += 1;
        return true;
    }

    function _buildInsurance() internal returns (bool) {
        // policy = PolicyInfo(1, 2);
        return true;
    }

    function expire() public returns (uint256) {
        return 1;
    }

    function claimPolicy() public returns (uint256) {
        return 1;
    }
}
