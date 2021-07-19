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

    /**
     * @notice start a new policy application
     * @param _userAddress: user's address
     * @param _productId: ID of the purchased product
     * @param _premium: premium of this policy
     * @param _payoff: payoff of this policy
     * @param _expiryDate: expiry date of this policy
     */
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

    /**
     * @notice check the policy and then determine whether we can afford it
     * @param _policyInfo: the info of the policy sold
     */
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

    /**
     * @notice update the policy when it is expired
     * @param _policyInfo: the info of the policy sold
     */
    function policyExpired(policyInfo memory _policyInfo) public {
        insurancePool.updateWhenExpire(_policyInfo.premium, _policyInfo.payoff);
        emit PolicyExpired(_policyInfo.policyId, _policyInfo.buyerAddress);
    }

    /**
     * @notice update the policy when it is claimed
     * @param _policyInfo: the info of the policy sold
     */
    function policyClaimed(policyInfo memory _policyInfo) public {
        insurancePool.payClaim(_policyInfo.payoff);
        emit PolicyClaimed(_policyInfo.policyId, _policyInfo.buyerAddress);
    }
}
