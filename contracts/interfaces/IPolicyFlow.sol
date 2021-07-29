// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPolicyFlow {
    struct policyInfo {
        uint256 productId;
        address buyerAddress;
        bytes32 policyId;
        uint256 premium;
        uint256 payoff;
        uint256 expiryDate;
        bool isClaimed;
    }

    event newPolicyApplication(bytes32 _policyID, address);
    event PolicySold(bytes32 _policyID, address);
    event PolicyDeclined(bytes32 _policyID, address);
    event PolicyClaimed(bytes32 _policyID, address);
    event PolicyExpired(bytes32 _policyID, address);

    function newApplication(
        address _userAddress,
        uint256 _productId,
        uint256 _premium,
        uint256 _payoff,
        uint256 _expiryDate
    ) external returns (string memory);

    function policyCheck(policyInfo memory _policyInfo) external;

    function policyExpired(policyInfo memory _policyInfo) external;

    function policyClaimed(policyInfo memory _policyInfo) external;
}
