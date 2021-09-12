// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/PolicyTypes.sol";
import "./libraries/ToStrings.sol";
import "./interfaces/IInsurancePool.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IPolicyToken.sol";

contract PolicyFlow is ChainlinkClient, PolicyTypes, ToStrings {
    using Chainlink for Chainlink.Request;
    using Strings for uint256;

    uint256 public oracleResponse; // A test variable to store the oracle address
    uint256 fee;
    string private FLIGHT_STATUS_URL = "http://39.101.132.228:8000/live/";
    address private oracleAddress;
    bytes32 private jobId;

    mapping(bytes32 => uint256) requestList; // requestId => total order
    mapping(uint256 => uint256) resultList; // total order => delay result

    address public owner;
    IInsurancePool insurancePool;
    IPolicyToken policyToken;

    // Minimum time before departure for applying
    uint256 public constant MIN_TIME_BEFORE_DEPARTURE = 24 hours;
    uint256 public DELAY_THRESHOLD = 240;
    uint256 Total_Policies;

    // Mappings
    mapping(bytes32 => PolicyInfo) policyList; // policyId => policyInfo
    mapping(uint256 => bytes32) policyOrderList; // total order => policyId

    mapping(address => uint256[]) userPolicy; // uint256[]: those totalOrders of a user
    mapping(address => uint256) userPolicyCount; // userAddress => user policy amount

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
        fee = 1 * 10**18; // 1 LINK

        // Initialized the count (do not need to initialize)
        Total_Policies = 0;
    }

    // ************************************ Modifiers ************************************ //

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

    // ************************************ View Functions ************************************ //

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
                            bytes32ToString(policyid),
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
     * @notice get a user's policy amount
     * @param _userAddress: user's address
     */
    function getUserPolicyCount(address _userAddress)
        public
        view
        returns (uint256)
    {
        return userPolicyCount[_userAddress];
    }

    /**
     * @notice get the policy buyer by policyId
     */
    function findPolicyBuyerById(bytes32 _policyId)
        public
        view
        returns (address)
    {
        return policyList[_policyId].buyerAddress;
    }

    // ************************************ Helper Functions ************************************ //

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
     * @notice set the new delay threshold
     */
    function setDelayThreshold(uint256 _threshold) public onlyOwner {
        DELAY_THRESHOLD = _threshold;
    }

    // ************************************ Main Functions ************************************ //

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
            404
        );

        // Store the policy's total order with userAddress
        userPolicy[_userAddress].push(Total_Policies);
        // Update the user's policy amount
        userPolicyCount[_userAddress] += 1;
        // Update the policyOrderList
        policyOrderList[Total_Policies] = TEMP_policyId;
        // Update total policies
        Total_Policies += 1;

        emit newPolicyApplication(TEMP_policyId, _userAddress);

        // Check the policy with the insurance pool status
        // May be accepted or rejected
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
        // Whether there are enough capacity in the pool
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
        oracleResponse = _data;

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
                policyList[policyId].payoff,
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
        uint256 payoff = 0;

        // payoff model 1 - linear
        if (_delay <= 60) {
            payoff = _delay;
        } else if (_delay > 60 && _delay <= 120) {
            payoff = 60 + (_delay - 60) * 2;
        } else if (_delay > 120 && _delay <= 240) {
            payoff = 180 + (_delay - 120) * 3;
        }

        payoff = payoff * 1e18;
        return payoff;
    }
}
