// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// import "./interfaces/IPolicyFlow.sol";
import "./libraries/Policy.sol";
import "./interfaces/IInsurancePool.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IPolicyToken.sol";

contract PolicyFlow is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using Strings for uint256;

    uint256 volume; // A test variable
    uint256 fee;
    address private oracle;
    bytes32 private jobId;

    address public owner;
    IInsurancePool insurancePool;
    IPolicyToken policyToken;
    address public oracleAddress;

    // Minimum time before departure for applying
    uint256 public constant MIN_TIME_BEFORE_DEPARTURE = 24 hours;
    uint256 Total_Policies;

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
        uint256 totalOrder;
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
    event FulfilledOracleRequest(bytes32 _policyId, bytes32 _requestId);

    mapping(bytes32 => policyInfo) policyList;
    mapping(uint256 => bytes32) policyList2;

    mapping(bytes32 => bytes32) requestList;

    mapping(address => uint256[]) userPolicy;
    mapping(address => uint256) userPolicyCount;

    constructor(
        IInsurancePool _insurancePool,
        IPolicyToken _policyToken,
        address _oracleAddress
    ) {
        owner = msg.sender;
        insurancePool = _insurancePool;
        policyToken = _policyToken;
        oracleAddress = _oracleAddress;
        Total_Policies = 0;

        setPublicChainlinkToken();
        oracle = 0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e;
        jobId = "b0bde308282843d49a3a8d2dd2464af1";
        fee = 0.1 * 10**18;
    }

    modifier onlyOracle() {
        require(
            msg.sender == oracleAddress,
            "only the oracle can call this function"
        );
        _;
    }

    /**
     * @notice show a user's policies (all)
     * @param _userAddress: user's address (buyer)
     * @return user's policy details
     */
    function viewPolicy(address _userAddress)
        public
        view
        returns (string memory)
    {
        require(userPolicyCount[_userAddress] > 0, "no policy for this user");

        uint256 policyCount = userPolicyCount[_userAddress];
        string memory result = "RESULT:";
        for (uint256 i = 0; i < policyCount; i++) {
            uint256 policyOrder = userPolicy[_userAddress][i];

            bytes32 policyid = policyList2[policyOrder];
            // string memory s_policyId = bytes32ToStr(policyid);
            uint256 status = uint256(policyList[policyid].status);
            result = string(
                abi.encodePacked(
                    result,
                    string(
                        abi.encodePacked(
                            // "{Policy",
                            // i.toString(),
                            "{PolicyId: ",
                            byToString(policyid),
                            ", ProductId: ",
                            policyList[policyid].productId.toString(),
                            ", buyerAddress: ",
                            addressToString(policyList[policyid].buyerAddress),
                            ", premium: ",
                            (policyList[policyid].premium / 10**18).toString(),
                            ", payoff: ",
                            (policyList[policyid].payoff / 10**18).toString(),
                            ", status: ",
                            status.toString(),
                            "}"
                        )
                    )
                )
            );
        }
        return result;
    }

    function addressToString(address addr)
        internal
        pure
        returns (string memory)
    {
        return (uint256(uint160(addr))).toHexString(20);
    }

    function byToString(bytes32 _bytes) internal pure returns (string memory) {
        return (uint256(_bytes)).toHexString(32);
    }

    function bytes32ToString(bytes32 _bytes32)
        public
        pure
        returns (string memory)
    {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function getPolicyIdByCount(uint256 _count) public view returns (bytes32) {
        return policyList2[_count];
    }

    function getPolicyInfoByCount(uint256 _count)
        public
        view
        returns (
            bytes32 _policyId,
            uint256 _productId,
            address _owner,
            uint256 _premium,
            uint256 _payoff,
            uint256 _expiryDate
        )
    {
        bytes32 policyId = policyList2[_count];
        return (
            policyId,
            policyList[policyId].productId,
            policyList[policyId].buyerAddress,
            policyList[policyId].premium,
            policyList[policyId].payoff,
            policyList[policyId].expiryDate
        );
    }

    function getTotalPolicyCount() public view returns (uint256) {
        return Total_Policies;
    }

    function getVolume() public view returns (uint256) {
        return volume;
    }

    function getUserPolicyCount(address _userAddress)
        public
        view
        returns (uint256)
    {
        return userPolicyCount[_userAddress];
    }

    function findPolicyBuyerById(bytes32 _policyId)
        public
        view
        returns (address)
    {
        return policyList[_policyId].buyerAddress;
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
     * @param _userAddress: user's address (buyer)
     * @param _productId: ID of the purchased product (0: flightdelay; 1,2,3...: others) (different products)
     * @param _premium: premium of this policy (decimal 18)
     * @param _payoff: payoff of this policy (decimal 18)
     * @param _expiryDate: expiry date of this policy (unix timestamp)
     */
    function newApplication(
        address _userAddress,
        uint256 _productId,
        uint256 _premium,
        uint256 _payoff,
        uint256 _expiryDate
    ) public returns (string memory) {
        // Check the buying time not too close to the departure time
        require(
            _expiryDate >= block.timestamp + MIN_TIME_BEFORE_DEPARTURE,
            "ERROR::TIME_TO_DEPARTURE_TOO_SMALL"
        );
        // Generate the unique policyId
        bytes32 TEMP_policyId = keccak256(
            abi.encodePacked(
                _userAddress,
                _productId,
                _expiryDate,
                Total_Policies
            )
        );
        // Generate the policy
        policyList[TEMP_policyId] = policyInfo(
            _productId,
            _userAddress,
            Total_Policies,
            TEMP_policyId,
            _premium,
            _payoff,
            _expiryDate,
            PolicyStatus.INI
        );
        userPolicy[_userAddress].push(Total_Policies); //store the policyID with userAddress
        userPolicyCount[_userAddress] += 1;

        policyList2[Total_Policies] = TEMP_policyId;
        Total_Policies += 1;
        //string memory policyId_RETURN = bytesToString(TEMP_policyId);
        emit newPolicyApplication(TEMP_policyId, _userAddress);
        // Check the policy with the insurance pool status
        policyCheck(_premium, _payoff, _userAddress, TEMP_policyId);
        return string(abi.encodePacked(TEMP_policyId));
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
        bool _isAccepted = insurancePool.updateWhenBuy(
            _premium,
            _payoff,
            _userAddress
        );
        if (_isAccepted) {
            policyList[_policyId].status = PolicyStatus.SOLD;
            emit PolicySold(_policyId, _userAddress);
            policyToken.mintPolicyToken(_userAddress);
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

    function policyFinalCheck(uint256 _policyOrder)
        public
        returns (bytes32 _requestId)
    {
        // request final status from chainlink, return requestId
        // Set the callback function as "policyStatusCallback"
        bytes32 policyId = policyList2[_policyOrder];

        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        // Set the URL to perform the GET request on
        request.add(
            "get",
            "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD"
        );

        request.add("path", "RAW.ETH.USD.VOLUME24HOUR");

        // Multiply the result by 1000000000000000000 to remove decimals
        int256 timesAmount = 10**18;
        request.addInt("times", timesAmount);

        // Sends the request
        bytes32 requestId = sendChainlinkRequestTo(oracle, request, fee);
        requestList[requestId] = policyId;
        return requestId;
    }

    function fulfill(bytes32 _requestId, uint256 _volume)
        public
        recordChainlinkFulfillment(_requestId)
    {
        volume = _volume;
        bytes32 policyId = requestList[_requestId];
        if (volume % 2 == 0) {
            policyExpired(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].buyerAddress,
                policyId
            );
        } else {
            policyClaimed(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].buyerAddress,
                policyId
            );
        }

        emit FulfilledOracleRequest(policyId, _requestId);
    }

    function policyStatusCallback(bytes32 _requestId, bytes32 _response)
        public
        onlyOracle
    {
        // Take different actions with the _response
        // ['canclled', 'delayed', 'delaytime'] bool, bool, uint256
    }

    function bytesToString(bytes32 _bytes) internal returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint256 charCount = 0;
        for (uint256 j = 0; j < 32; j++) {
            bytes1 char = bytes1(bytes32(uint256(_bytes) * 2**(8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint256 j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
}
