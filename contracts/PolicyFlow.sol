// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// import "./interfaces/IPolicyFlow.sol";
import "./libraries/Policy.sol";
import "./interfaces/IInsurancePool.sol";

contract PolicyFlow {
    address public owner;
    IInsurancePool insurancePool;
    address public oracleAddress;

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

    mapping(address => policyInfo) policyList;

    constructor(IInsurancePool _insurancePool, address _oracleAddress) {
        owner = msg.sender;
        insurancePool = _insurancePool;
        oracleAddress = _oracleAddress;
    }

    function newApplication(
        address _userAddress,
        uint256 _productId,
        uint256 _premium,
        uint256 _payoff,
        uint256 _expiryDate
    ) public returns (bytes32) {
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
        return TEMP_policyId;
    }

    function policyCheck(policyInfo memory _policyInfo) public {
        bool _isAccepted = insurancePool.updateWhenBuy(
            _policyInfo.premium,
            _policyInfo.payoff
        );
        if (_isAccepted) {
            emit PolicySold(_policyInfo.policyId, _policyInfo.buyerAddress);
        } else {
            emit PolicyDeclined(_policyInfo.policyId, _policyInfo.buyerAddress);
        }
    }

    function policyExpired(policyInfo memory _policyInfo) public {
        emit PolicyExpired(_policyInfo.policyId, _policyInfo.buyerAddress);
    }

    function policyClaimed(policyInfo memory _policyInfo) public {
        emit PolicyClaimed(_policyInfo.policyId, _policyInfo.buyerAddress);
    }
}
