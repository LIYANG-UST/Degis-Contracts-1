// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IPolicyFlow.sol";
import "./libraries/Policy.sol";

contract PolicyFlow is IPolicyFlow {
    address public owner;

    struct policyInfo {
        uint256 productId;
        address buyerAddress;
        bytes32 policyId;
        uint256 premium;
        uint256 payoff;
        uint256 expiryDate;
        bool isClaimed;
    }

    mapping(address => policyInfo) policyList;

    constructor() {}

    function newApplication(
        address _userAddress,
        uint256 _productId,
        uint256 _premium,
        uint256 _payoff,
        uint256 _expiryDate
    ) public returns (uint256) {
        bytes32 TEMP_policyId = keccak256(
            abi.encodePacked(_userAddress, _productId, _expiryDate)
        );
        policyList[_userAddress] = policyInfo(
            _productId,
            _userAddress,
            TEMP_policyId,
            _premium,
            _payoff,
            _expiryDate,
            false
        );
        emit newPolicyApplication(TEMP_policyId, _userAddress);
    }

    function policySold() external returns (uint256) {}

    function policyDeclined() external {}

    function policyExpired() external {}

    function policyClaimed() external {}
}
