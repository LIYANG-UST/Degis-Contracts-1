// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// import "./interfaces/IPolicyFlow.sol";
import "./libraries/Policy.sol";
import "./libraries/ToStrings.sol";
import "./interfaces/IInsurancePool.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IPolicyToken.sol";

contract PolicyFlow is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using Strings for uint256;

    uint256 public response; // A test variable
    uint256 fee;
    string constant FLIGHT_STATUS_URL = "http://39.101.132.228:8000/live/";
    address private oracleAddress;
    bytes32 private jobId;

    enum RequestStatus {
        INIT,
        SENT,
        COMPLETED
    }

    mapping(bytes32 => uint256) requestList; // requestId => total order
    mapping(uint256 => uint256) resultList; // total order => delay result

    address public owner;
    IInsurancePool insurancePool;
    IPolicyToken policyToken;

    // Minimum time before departure for applying
    uint256 public constant MIN_TIME_BEFORE_DEPARTURE = 24 hours;
    uint256 public DELAY_THRESHOLD = 240;
    uint256 Total_Policies;

    enum PolicyStatus {
        INI,
        SOLD,
        DECLINED,
        EXPIRED,
        CLAIMED
    }

    struct PolicyInfo {
        uint256 productId; // 0: flight delay 1,2,3: future products
        address buyerAddress; // buyer's address
        uint256 totalOrder; // total order: 0 - N (unique for each policy)(used to link)
        bytes32 policyId; // unique ID (bytes32) for this policy
        uint256 premium;
        uint256 payoff;
        uint256 purchaseDate; // Unix timestamp
        uint256 departureDate; // Unix timestamp
        PolicyStatus status; // INI, SOLD, DECLINED, EXPIRED, CLAIMED
        // Oracle Related
        bool isUsed; // Whether has call the oracle
        uint256 delayResult; // [400:cancelled] [0: on time] [0 ~ 240: delay time] [404: initial]
    }

    // Events list
    event newPolicyApplication(bytes32 _policyID, address);
    event PolicySold(bytes32 _policyID, address);
    event PolicyDeclined(bytes32 _policyID, address);
    event PolicyClaimed(bytes32 _policyID, address);
    event PolicyExpired(bytes32 _policyID, address);
    event FulfilledOracleRequest(bytes32 _policyId, bytes32 _requestId);

    // Mappings
    mapping(bytes32 => PolicyInfo) policyList; // policyId => policyInfo
    mapping(uint256 => bytes32) policyOrderList; // total order => policyId

    mapping(address => uint256[]) userPolicy; // uint256[]: those totalOrders of a user
    mapping(address => uint256) userPolicyCount;

    // Constructor Function
    constructor(
        IInsurancePool _insurancePool,
        IPolicyToken _policyToken,
        address _oracleAddress
    ) {
        // set owner address
        owner = msg.sender;

        // set two interfaces' addresses
        insurancePool = _insurancePool;
        policyToken = _policyToken;

        // set oracle
        oracleAddress = _oracleAddress;
        jobId = "cef74a7ff7ea4194ab97f00c89abef6b";
        setPublicChainlinkToken();
        fee = 1 * 10**18;

        // Initialized the count
        Total_Policies = 0;
    }

    modifier onlyOracle() {
        require(
            msg.sender == oracleAddress,
            "only the oracle can call this function"
        );
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner can call this function");
        _;
    }

    /**
     * @notice change the job id
     * @param _jobId: new job Id
     */
    function changeJobId(bytes32 _jobId) public onlyOwner {
        jobId = _jobId;
    }

    /**
     * @notice change the oracle fee
     * @param _fee: new fee
     */
    function changeFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    /**
     * @notice change the oracle address
     * @param _oracleAddress: new oracle address
     */
    function changeOrcaleAddress(address _oracleAddress) public onlyOwner {
        oracleAddress = _oracleAddress;
    }

    /**
     * @notice show the current job id
     */
    function getJobId() public view onlyOwner returns (bytes32) {
        return jobId;
    }

    /**
     * @notice show the current oracle address
     */
    function getOrcaleAddress() public view onlyOwner returns (address) {
        return oracleAddress;
    }

    /**
     * @notice Returns the address of the LINK token
     * @dev This is the public implementation for chainlinkTokenAddress, which is
     * an internal method of the ChainlinkClient contract
     */
    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
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
        string memory result = " ";
        for (uint256 i = 0; i < policyCount; i++) {
            uint256 policyOrder = userPolicy[_userAddress][i];

            bytes32 policyid = policyOrderList[policyOrder];
            // string memory s_policyId = bytes32ToStr(policyid);
            uint256 status = uint256(policyList[policyid].status);
            string memory isUsed = policyList[policyid].isUsed
                ? "used"
                : "not used";
            result = string(
                abi.encodePacked(
                    result,
                    string(
                        abi.encodePacked(
                            "\nPolicy",
                            i.toString(),
                            ": \n{PolicyId: ",
                            byToString(policyid),
                            ", \nProductId: ",
                            policyList[policyid].productId.toString(),
                            ", \nbuyerAddress: ",
                            addressToString(policyList[policyid].buyerAddress),
                            ", \npremium: ",
                            (policyList[policyid].premium / 10**18).toString(),
                            ", \npayoff: ",
                            (policyList[policyid].payoff / 10**18).toString(),
                            ", \nstatus: ",
                            status.toString(),
                            ", \nisUsed: ",
                            isUsed,
                            ", \ndelay results: ",
                            policyList[policyid].delayResult.toString(),
                            "}"
                        )
                    )
                )
            );
        }
        return result;
    }

    /**
     * @notice transfer an address to a string
     * @param _addr: input address
     * @return string form of _addr
     */
    function addressToString(address _addr)
        internal
        pure
        returns (string memory)
    {
        return (uint256(uint160(_addr))).toHexString(20);
    }

    /**
     * @notice transfer bytes32 to string (not change the content)
     * @param _bytes: input bytes32
     * @return string form of _bytes
     */
    function byToString(bytes32 _bytes) internal pure returns (string memory) {
        return (uint256(_bytes)).toHexString(32);
    }

    /**
     * @notice transfer bytes32 to string (human-readable form)
     * @param _bytes: input bytes32
     * @return string form of _bytes
     */
    function bytes32ToString(bytes32 _bytes)
        public
        pure
        returns (string memory)
    {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes[i];
        }
        return string(bytesArray);
    }

    /**
     * @notice get the policyId (bytes32) from its count/order
     * @param _count: total count
     * @return policyId (bytes32)
     */
    function getPolicyIdByCount(uint256 _count) public view returns (bytes32) {
        return policyOrderList[_count];
    }

    /**
     * @notice get the policyInfo from its count/order
     * @param _count: total count
     */
    function getPolicyInfoByCount(uint256 _count)
        public
        view
        returns (
            bytes32 _policyId,
            uint256 _productId,
            address _owner,
            uint256 _premium,
            uint256 _payoff,
            uint256 _departureDate
        )
    {
        bytes32 policyId = policyOrderList[_count];
        return (
            policyId,
            policyList[policyId].productId,
            policyList[policyId].buyerAddress,
            policyList[policyId].premium,
            policyList[policyId].payoff,
            policyList[policyId].departureDate
        );
    }

    /**
     * @notice get the total policy count
     * @return total policy count
     */
    function getTotalPolicyCount() public view returns (uint256) {
        return Total_Policies;
    }

    function getResponse() public view returns (uint256) {
        return response;
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

    function setDelayThreshold(uint256 _threshold) public {
        DELAY_THRESHOLD = _threshold;
    }

    function getDelayThreshold() public view returns (uint256) {
        return DELAY_THRESHOLD;
    }

    /**
     * @notice start a new policy application
     * @param _userAddress: user's address (buyer)
     * @param _productId: ID of the purchased product (0: flightdelay; 1,2,3...: others) (different products)
     * @param _premium: premium of this policy (decimal 18)
     * @param _payoff: payoff of this policy (decimal 18)
     * @param _departureDate: expiry date of this policy (unix timestamp)
     */
    function newApplication(
        address _userAddress,
        uint256 _productId,
        uint256 _premium,
        uint256 _payoff,
        uint256 _departureDate
    ) public returns (bytes32 _policyId) {
        // Check the buying time not too close to the departure time
        require(
            _departureDate >= block.timestamp + MIN_TIME_BEFORE_DEPARTURE,
            "ERROR::TIME_TO_DEPARTURE_TOO_SMALL"
        );
        // Generate the unique policyId
        bytes32 TEMP_policyId = keccak256(
            abi.encodePacked(
                _userAddress,
                _productId,
                _departureDate,
                Total_Policies
            )
        );
        uint256 TEMP_purchaseDate = block.timestamp;
        // Generate the policy
        policyList[TEMP_policyId] = PolicyInfo(
            _productId,
            _userAddress,
            Total_Policies,
            TEMP_policyId,
            _premium,
            _payoff,
            TEMP_purchaseDate,
            _departureDate,
            PolicyStatus.INI,
            false,
            800
        );

        userPolicy[_userAddress].push(Total_Policies); //store the policyID with userAddress
        userPolicyCount[_userAddress] += 1;

        policyOrderList[Total_Policies] = TEMP_policyId;
        Total_Policies += 1;

        //string memory policyId_RETURN = bytesToString(TEMP_policyId);
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

    // /**
    //  * @notice Check the final delay status of the flight
    //  * @param _policyOrder: the unique policy total order
    //  */
    // function policyFinalCheck(uint256 _policyOrder)
    //     public
    //     returns (bytes32 _requestId)
    // {
    //     // request final status from chainlink, return requestId
    //     // Set the callback function as "policyStatusCallback"
    //     bytes32 policyId = policyOrderList[_policyOrder];

    //     Chainlink.Request memory request = buildChainlinkRequest(
    //         jobId,
    //         address(this),
    //         this.fulfill.selector
    //     );

    //     // Set the URL to perform the GET request on
    //     request.add(
    //         "get",
    //         "https://api.coingecko.com/api/v3/simple/price?ids=chainlink&vs_currencies=USD"
    //     );

    //     request.add("path", "chainlink.usd");

    //     // Multiply the result by 1000000000000000000 to remove decimals
    //     int256 timesAmount = 10**2;
    //     request.addInt("times", timesAmount);

    //     // Sends the request
    //     bytes32 requestId = sendChainlinkRequestTo(oracleAddress, request, fee);
    //     requestList[requestId] = policyId;
    //     return requestId;
    // }

    /** @notice calculate the flight status
     *  @param _policyOrder The total order of the policy
     *  @param _flightNumber The flight number
     *  @param _date The flight date
     *  @param _path Which data in json needs to get
     *  @param _forceUpdate Owner can force to update
     */
    function calculateFlightStatus(
        uint256 _policyOrder,
        string memory _flightNumber,
        string memory _date,
        string memory _path,
        bool _forceUpdate
    ) public {
        bytes32 _policyId = policyOrderList[_policyOrder];
        require(
            (!policyList[_policyId].isUsed) ||
                (_forceUpdate && (msg.sender == owner)),
            "The policy has been final checked, or you need to force update"
        );

        string memory _url = string(
            abi.encodePacked(
                FLIGHT_STATUS_URL,
                _flightNumber,
                "/timestamp=",
                _date
            )
        );
        bytes32 requestId = createRequestTo(
            oracleAddress,
            jobId,
            fee,
            _url,
            _path,
            1
        );
        requestList[requestId] = _policyOrder;
        policyList[_policyId].isUsed = true;
    }

    /**
     * @notice Creates a request to the specified Oracle contract address
     * @dev This function ignores the stored Oracle contract address and
     * will instead send the request to the address specified
     * @param _oracle The Oracle contract address to send the request to
     * @param _jobId The bytes32 JobID to be executed
     * @param _url The URL to fetch data from
     * @param _path The dot-delimited path to parse of the response
     * @param _times The number to multiply the result by
     */
    function createRequestTo(
        address _oracle,
        bytes32 _jobId,
        uint256 _payment,
        string memory _url,
        string memory _path,
        int256 _times
    ) private returns (bytes32) {
        Chainlink.Request memory req = buildChainlinkRequest(
            _jobId,
            address(this),
            this.fulfill.selector
        );
        req.add("url", _url);
        req.add("path", _path);
        req.addInt("times", _times);
        return sendChainlinkRequestTo(_oracle, req, _payment);
    }

    /**
     * @notice The fulfill method from requests created by this contract
     * @dev The recordChainlinkFulfillment protects this function from being called
     * by anyone other than the oracle address that the request was sent to
     * @param _requestId The ID that was generated for the request
     * @param _data The answer provided by the oracle
     */
    function fulfill(bytes32 _requestId, uint256 _data)
        public
        recordChainlinkFulfillment(_requestId)
    {
        response = _data;

        uint256 order = requestList[_requestId];
        bytes32 policyId = policyOrderList[order];
        policyList[policyId].delayResult = _data;

        if (_data == 0) {
            // 0: on time
            policyExpired(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].buyerAddress,
                policyId
            );
        } else if (_data <= DELAY_THRESHOLD) {
            uint256 payoff = calcPayoff(_data);
            if (payoff < policyList[policyId].payoff) {
                policyClaimed(
                    policyList[policyId].premium,
                    payoff,
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
        } else if (_data == 400) {
            // 400: cancelled
            policyClaimed(
                policyList[policyId].premium,
                policyList[policyId].payoff / 4,
                policyList[policyId].buyerAddress,
                policyId
            );
        } else {
            policyExpired(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].buyerAddress,
                policyId
            );
        }

        emit FulfilledOracleRequest(policyId, _requestId);
    }

    /**
     * @notice The payoff formula
     * @param _delay Delay in minutes
     * @return the final payoff volume
     */
    function calcPayoff(uint256 _delay) internal pure returns (uint256) {
        uint256 payoff = ((_delay**2) / 40) * 1e18;
        return payoff;
    }

    /**
     * @notice Transfer a bytes(ascii) to uint
     * @param s input bytes
     * @return the number
     */
    function bytesToUint(bytes32 s) public pure returns (uint256) {
        bytes memory b = new bytes(32);
        for (uint256 i; i < 32; i++) {
            b[i] = s[i];
        }
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48);
            }
        }
        return result;
    }
}
