// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// import "./interfaces/IPolicyFlow.sol";
import "./libraries/Policy.sol";
import "./interfaces/IInsurancePool.sol";

contract PolicyFlow {
    address public owner;
    IInsurancePool insurancePool;
    address public oracleAddress;

    enum PolicyStatus {
        INI,
        SOLD,
        DECLINED,
        EXPIRED,
        CLAIMED
    }

    struct policyInfo {
        uint256 productId; // 0: flight delay
        address buyerAddress;
        bytes32 policyId; // unique ID for this policy
        uint256 premium;
        uint256 payoff;
        uint256 expiryDate;
        PolicyStatus status;
    }
    event newPolicyApplication(bytes32 _policyID, address);
    event PolicySold(bytes32 _policyID, address);
    event PolicyDeclined(bytes32 _policyID, address);
    event PolicyClaimed(bytes32 _policyID, address);
    event PolicyExpired(bytes32 _policyID, address);

    mapping(bytes32 => policyInfo) policyList;
    mapping(address => bytes32[]) userPolicy;
    mapping(address => uint256) userPolicyCount;

    constructor(IInsurancePool _insurancePool, address _oracleAddress) {
        owner = msg.sender;
        insurancePool = _insurancePool;
        oracleAddress = _oracleAddress;
    }

    function viewPolicy(address _userAddress)
        public
        view
        returns (string memory)
    {
        require(userPolicy[_userAddress].length > 0, "no policy for this user");
        uint256 policyCount = userPolicyCount[_userAddress];
        string memory result;
        for (uint256 i = 0; i < userPolicy[_userAddress].length; i++) {
            bytes32 policyid = userPolicy[_userAddress][policyCount];
            result = string(
                abi.encodePacked(
                    result,
                    string(
                        abi.encodePacked(
                            '{"ProductId":"',
                            policyList[policyid].productId,
                            '", "description":"',
                            policyList[policyid].premium,
                            policyList[policyid].payoff,
                            '", "status": "',
                            policyList[policyid].status,
                            '"}'
                        )
                    )
                )
            );
        }
        return result;
    }

    function getPolicyCount(address _userAddress)
        public
        view
        returns (uint256)
    {
        return userPolicyCount[_userAddress];
    }

    function findPolicyBuyerById(string memory _policyId)
        public
        view
        returns (address)
    {
        bytes32 result = string2bytes(_policyId);
        return policyList[result].buyerAddress;
    }

    function string2bytes(string memory _in)
        internal
        pure
        returns (bytes32 result)
    {
        assembly {
            result := mload(add(_in, 32))
        }
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
        policyList[TEMP_policyId] = policyInfo(
            _productId,
            _userAddress,
            TEMP_policyId,
            _premium,
            _payoff,
            _expiryDate,
            PolicyStatus.INI
        ); //Initialized
        userPolicy[_userAddress].push(TEMP_policyId); //store the policyID with userAddress
        userPolicyCount[_userAddress] += 1;
        emit newPolicyApplication(TEMP_policyId, _userAddress);
        // Check the policy with the insurance pool status
        policyCheck(_premium, _payoff, _userAddress, TEMP_policyId);
        return TEMP_policyId;
    }

    /**
     * @notice check the policy and then determine whether we can afford it
     * @param _premium: the premium of the policy sold
     * @param _payoff: the payoff of the policy sold
     * @param _userAddress: user's address
     * @param _policyId: the unique policy ID
     */
    function policyCheck(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        bytes32 _policyId
    ) public {
        bool _isAccepted = insurancePool.updateWhenBuy(_premium, _payoff);
        if (_isAccepted) {
            policyList[_policyId].status = PolicyStatus.SOLD;
            emit PolicySold(_policyId, _userAddress);
        } else {
            policyList[_policyId].status = PolicyStatus.DECLINED;
            emit PolicyDeclined(_policyId, _userAddress);
        }
    }

    /**
     * @notice update the policy when it is expired
     * @param _premium: the premium of the policy sold
     * @param _payoff: the payoff of the policy sold
     * @param _userAddress: user's address
     * @param _policyId: the unique policy ID
     */
    function policyExpired(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        bytes32 _policyId
    ) public {
        insurancePool.updateWhenExpire(_premium, _payoff);
        policyList[_policyId].status = PolicyStatus.EXPIRED;
        emit PolicyExpired(_policyId, _userAddress);
    }

    /**
     * @notice update the policy when it is claimed
     * @param _payoff: the payoff of the policy sold
     * @param _userAddress: user's address
     * @param _policyId: the unique policy ID
     */
    function policyClaimed(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        bytes32 _policyId
    ) public {
        insurancePool.payClaim(_premium, _payoff, _userAddress);
        policyList[_policyId].status = PolicyStatus.CLAIMED;
        emit PolicyClaimed(_policyId, _userAddress);
    }
}
