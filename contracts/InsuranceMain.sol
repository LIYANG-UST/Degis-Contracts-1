// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InsurancePool.sol";


contract InsuranceMain {

    struct PolicyInfo {
        uint256 payoff;
        uint256 expiryTime;
    }

    InsurancePool pool_contract;

    address public owner;

    mapping(address => mapping(uint256 => PolicyInfo)) userPolicyInfo;
    mapping(address => uint256) userPolicyIndex;

    constructor(_pool_addr) {
        owner = msg.sender;
        pool_contract = InsurancePool(_pool_addr);
    }


    function buyInsurance(PolicyInfo _policy) public returns(bool) {
        calcPremium();

        checkWhenBuy();
        updateWhenBuy();

        //updateUserInfo();
        //updateInsurancePool();


        policy = _buildInsurance();
        index = userPolicyIndex[user_add];    
        userPolicyInfo[user_add][index + 1] = policy;
        userPolicyIndex += 1;
    }

    function _buildInsurance() internal returns(PolicyInfo policy){
        policy = PolicyInfo(1, 2);
        return policy;
    }
}