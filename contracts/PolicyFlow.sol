// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IInsurancePool.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IFDPolicyToken.sol";
import "./interfaces/IPolicyFlow.sol";
import "./interfaces/IFlightOracle.sol";
import "./interfaces/ISigManager.sol";
import "./interfaces/tokens/IBuyerToken.sol";

/**
 * @title  PolicyFlow
 * @notice This is the policy flow contract which is responsible for the whole lifecycle of a policy.
 *         Every policy's information are stored in this contract.
 *         A policy will have a unique "_policyId":
 *
 *          The total order in this product. Should be equal to its ERC721 tokenId
 *
 *         The main functions of a policy are: newApplication & newClaimRequest.
 *         We use Chainlink in this contract to get the final status of a flight.
 */
contract PolicyFlow is ChainlinkClient, IPolicyFlow {
    /// @notice Using some libraries
    using Chainlink for Chainlink.Request;
    using Strings for uint256;

    uint256 constant PRODUCT_ID = 0;

    uint256 public oracleResponse; // A test variable to store the oracle address

    uint256 fee;
    string public FLIGHT_STATUS_URL =
        "https://18.163.254.50:3207/flight_status?";

    mapping(bytes32 => uint256) requestList; // requestId => policyId
    mapping(uint256 => uint256) resultList; // policyId => delay result

    address public owner;

    ISigManager sigManager;
    IInsurancePool insurancePool;
    IFDPolicyToken policyToken;
    IFlightOracle flightOracle;
    IBuyerToken buyerToken;

    // Minimum time before departure for applying
    uint256 public MIN_TIME_BEFORE_DEPARTURE = 24 hours;

    // Parameters about the claim curve
    uint256 public MAX_PAYOFF = 180 ether;
    uint256 public DELAY_THRESHOLD_MIN = 30;
    uint256 public DELAY_THRESHOLD_MAX = 240;

    // Total amount of policies
    uint256 public Total_Policies;

    mapping(uint256 => PolicyInfo) policyList; // policyId => policyInfo

    mapping(address => uint256[]) userPolicy; // uint256[]: those policyIds of a user
    mapping(address => uint256) userPolicyCount; // userAddress => user policy amount

    /// @notice Constructor Function
    constructor(
        address _insurancePool,
        address _policyToken,
        address _sigManager,
        address _buyerToken
    ) {
        // Set owner address
        owner = msg.sender;

        // Other contracts' interfaces
        insurancePool = IInsurancePool(_insurancePool);
        policyToken = IFDPolicyToken(_policyToken);
        buyerToken = IBuyerToken(_buyerToken);
        sigManager = ISigManager(_sigManager);

        // Set oracle parameter
        fee = 1e17; // 0.1 LINK
    }

    // ----------------------------------------------------------------------------------- //
    // ************************************ Modifiers ************************************ //
    // ----------------------------------------------------------------------------------- //

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner can call this function");
        _;
    }

    modifier notZeroAddress() {
        require(msg.sender != address(0), "can not use zero address");
        _;
    }

    // ----------------------------------------------------------------------------------- //
    // ********************************* View Functions ********************************** //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice Returns the address of the LINK token
     * @dev This is the public implementation for chainlinkTokenAddress, which is
     *      an internal method of the ChainlinkClient contract
     */
    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    /**
     * @notice Show a user's policies (all)
     * @param _userAddress User's address (buyer)
     * @return userPolicies User's all policy details
     */
    function viewUserPolicy(address _userAddress)
        public
        view
        returns (PolicyInfo[] memory)
    {
        require(userPolicyCount[_userAddress] > 0, "no policy for this user");

        uint256 policyCount = userPolicyCount[_userAddress];

        PolicyInfo[] memory result = new PolicyInfo[](policyCount);

        for (uint256 i = 0; i < policyCount; i++) {
            uint256 policyId = userPolicy[_userAddress][i];

            result[i] = policyList[policyId];
        }
        return result;
    }

    /**
     * @notice Get the policyInfo from its count/order
     * @param _policyId Total count/order of the policy = NFT tokenId
     * @return policy A struct of information about this policy
     */
    function getPolicyInfoById(uint256 _policyId)
        public
        view
        returns (PolicyInfo memory policy)
    {
        policy = policyList[_policyId];
    }

    /**
     * @notice Get a user's total policy amount
     * @param _userAddress User's address
     * @return policyAmount User's policy amount
     */
    function getUserPolicyCount(address _userAddress)
        public
        view
        returns (uint256 policyAmount)
    {
        policyAmount = userPolicyCount[_userAddress];
    }

    /**
     * @notice Get the policy buyer by policyId
     * @param _policyId Unique policy Id (uint256)
     * @return buyerAddress The buyer of this policy
     */
    function findPolicyBuyerById(uint256 _policyId)
        public
        view
        returns (address buyerAddress)
    {
        buyerAddress = policyList[_policyId].buyerAddress;
    }

    // ----------------------------------------------------------------------------------- //
    // ******************************** Setting Functions ******************************** //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice Change the oracle fee
     * @param _fee New oracle fee
     */
    function changeFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
     * @notice Change the max payoff
     * @param _newMaxPayoff New maxpayoff amount
     */
    function changeMaxPayoff(uint256 _newMaxPayoff) external onlyOwner {
        MAX_PAYOFF = _newMaxPayoff;
    }

    /**
     * @notice How long before departure when users can not buy new policies
     * @param _newMinTime New time set
     */
    function changeMinTimeBeforeDeparture(uint256 _newMinTime)
        external
        onlyOwner
    {
        MIN_TIME_BEFORE_DEPARTURE = _newMinTime;
    }

    /**
     * @notice Change the oracle address
     * @param _oracleAddress New oracle address
     */
    function setFlightOracle(address _oracleAddress) external onlyOwner {
        flightOracle = IFlightOracle(_oracleAddress);
    }

    /**
     * @notice Set a new url
     */
    function setURL(string memory _url) external onlyOwner {
        FLIGHT_STATUS_URL = _url;
    }

    /**
     * @notice Set the new delay threshold used for calculating payoff
     * @param _thresholdMin New minimum threshold
     * @param _thresholdMax New maximum threshold
     */
    function setDelayThreshold(uint256 _thresholdMin, uint256 _thresholdMax)
        external
        onlyOwner
    {
        DELAY_THRESHOLD_MIN = _thresholdMin;
        DELAY_THRESHOLD_MAX = _thresholdMax;
        emit DelayThresholdSet(_thresholdMin, _thresholdMax);
    }

    // ----------------------------------------------------------------------------------- //
    // ********************************** Main Functions ********************************* //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice Buy a new policy application
     * @dev Get the signature from the backend server
     * @param _productId ID of the purchased product (0: flightdelay; 1,2,3...: others) (different products)
     * @param _flightNumber Flight number string (e.g. "AQ1299")
     * @param _premium Premium of this policy (decimals: 18)
     * @param _departureDate Departure date of this flight (unix timestamp in s, not ms!)
     * @param _landingDate Landing date of this flight (uinx timestamp in s, not ms!)
     * @param _deadline Deadline for this purchase request
     * @param signature Use web3.eth.sign(hash(data), account) to generate the signature
     */
    function newApplication(
        uint256 _productId,
        string memory _flightNumber,
        uint256 _premium,
        uint256 _departureDate,
        uint256 _landingDate,
        uint256 _deadline,
        bytes calldata signature
    ) public returns (uint256 _policyId) {
        require(
            block.timestamp <= _deadline,
            "Expired deadline, please resubmit a transaction"
        );

        require(
            _productId == PRODUCT_ID,
            "You are calling the wrong product contract"
        );

        require(
            _departureDate >= block.timestamp + MIN_TIME_BEFORE_DEPARTURE,
            "It's too close to the departure time, you cannot buy this policy"
        );

        // Should be signed by operators
        _checkSignature(
            signature,
            _flightNumber,
            msg.sender,
            _premium,
            _deadline
        );

        // Generate the policy
        uint256 currentPolicyId = Total_Policies;
        policyList[currentPolicyId] = PolicyInfo(
            PRODUCT_ID,
            msg.sender,
            currentPolicyId,
            _flightNumber,
            _premium,
            MAX_PAYOFF,
            block.timestamp,
            _departureDate,
            _landingDate,
            PolicyStatus.INI,
            false,
            404
        );

        // Check the policy with the insurance pool status
        // May be accepted or rejected, if accepted then update the status of insurancePool
        _policyCheck(_premium, MAX_PAYOFF, msg.sender, currentPolicyId);

        // Give buyer tokens depending on the usd value they spent
        buyerToken.mint(msg.sender, _premium);

        // Store the policy's total order with userAddress
        userPolicy[msg.sender].push(Total_Policies);

        // Update the user's policy amount
        userPolicyCount[msg.sender] += 1;

        // Update total policies
        Total_Policies += 1;

        emit newPolicyApplication(currentPolicyId, msg.sender);

        return currentPolicyId;
    }

    /** @notice Make a claim request
     *  @param _policyId The total order/id of the policy
     *  @param _flightNumber The flight number
     *  @param _date The flight departure date
     *  @param _path Which data in json needs to get
     *  @param _forceUpdate Owner can force to update
     */
    function newClaimRequest(
        uint256 _policyId,
        string memory _flightNumber,
        string memory _date,
        string memory _path,
        bool _forceUpdate
    ) public {
        // Can not get the result before landing date
        // Landing date may not be true, may be a fixed interval (4hours)
        require(
            block.timestamp >= policyList[_policyId].landingDate,
            "Can only claim a policy after its landing"
        );

        // Check if the policy has been settled
        require(
            (!policyList[_policyId].isUsed) ||
                (_forceUpdate && (msg.sender == owner)),
            "The policy status has already been settled, or you need to make a force update"
        );

        // Check if the flight number is correct
        require(
            keccak256(abi.encodePacked(_flightNumber)) ==
                keccak256(abi.encodePacked(policyList[_policyId].flightNumber)),
            "Wrong flight number provided"
        );

        // Check if the departure date is correct
        require(
            keccak256(abi.encodePacked(_date)) ==
                keccak256(
                    abi.encodePacked(policyList[_policyId].departureDate)
                ),
            "Wrong departure date provided"
        );

        // Construct the url for oracle
        string memory _url = string(
            abi.encodePacked(
                FLIGHT_STATUS_URL,
                "flight_no=",
                _flightNumber,
                "&timestamp=",
                _date
            )
        );

        // Start a new oracle request
        bytes32 requestId = flightOracle.newOracleRequest(fee, _url, _path, 1);

        // Record this request
        requestList[requestId] = _policyId;
        policyList[_policyId].isUsed = true;
    }

    /**
     * @notice Update information when a policy token's ownership has been transferred
     * @dev This function is called by the ERC721 contract of PolicyToken
     * @param _tokenId Token Id of the policy token
     * @param _oldOwner The initial owner
     * @param _newOwner The new owner
     */
    function policyOwnerTransfer(
        uint256 _tokenId,
        address _oldOwner,
        address _newOwner
    ) external override {
        // Check the call is from policy token contract
        require(
            msg.sender == address(policyToken),
            "only called from the policy token contract"
        );

        // Check the previous owner record
        uint256 policyId = _tokenId;
        require(
            _oldOwner == policyList[policyId].buyerAddress,
            "The previous owner is wrong"
        );

        // Update the new buyer address
        policyList[policyId].buyerAddress = _newOwner;
        emit PolicyOwnerTransfer(_tokenId, _newOwner);
    }

    // ----------------------------------------------------------------------------------- //
    // ********************************* Oracle Functions ******************************** //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice Do the final settlement, called by FlightOracle contract
     * @param _requestId Chainlink request id
     * @param _result Delay result (minutes) given by oracle
     */
    function finalSettlement(bytes32 _requestId, uint256 _result) public {
        // Check if the call is from flight oracle
        require(
            msg.sender == address(flightOracle),
            "this function should be called by FlightOracle contract"
        );

        // Store the oracle response
        oracleResponse = _result;

        uint256 policyId = requestList[_requestId];

        PolicyInfo storage policy = policyList[policyId];
        policy.delayResult = _result;

        uint256 premium = policy.premium;
        address buyerAddress = policy.buyerAddress;

        require(
            _result <= DELAY_THRESHOLD_MAX || _result == 400,
            "Abnormal oracle result, result should be [0 - 240] or 400"
        );

        if (_result == 0) {
            // 0: on time
            policyExpired(premium, MAX_PAYOFF, buyerAddress, policyId);
        } else if (_result <= DELAY_THRESHOLD_MAX) {
            uint256 real_payoff = calcPayoff(_result);
            _policyClaimed(premium, real_payoff, buyerAddress, policyId);
        } else if (_result == 400) {
            // 400: cancelled
            _policyClaimed(premium, MAX_PAYOFF, buyerAddress, policyId);
        }

        emit FulfilledOracleRequest(policyId, _requestId);
    }

    // ----------------------------------------------------------------------------------- //
    // ******************************** Internal Functions ******************************* //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice check the policy and then determine whether we can afford it
     * @param _payoff the payoff of the policy sold
     * @param _userAddress user's address
     * @param _policyId the unique policy ID
     */
    function _policyCheck(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        uint256 _policyId
    ) internal {
        // Whether there are enough capacity in the pool
        bool _isAccepted = insurancePool.checkCapacity(_payoff);

        if (_isAccepted) {
            insurancePool.updateWhenBuy(_premium, _payoff, _userAddress);
            policyList[_policyId].status = PolicyStatus.SOLD;
            emit PolicySold(_policyId, _userAddress);

            policyToken.mintPolicyToken(_userAddress);
        } else {
            policyList[_policyId].status = PolicyStatus.DECLINED;
            emit PolicyDeclined(_policyId, _userAddress);
            revert("not sufficient capacity in the insurance pool");
        }
    }

    /**
     * @notice update the policy when it is expired
     * @param _premium the premium of the policy sold
     * @param _payoff the payoff of the policy sold
     * @param _userAddress user's address
     * @param _policyId the unique policy ID
     */
    function policyExpired(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        uint256 _policyId
    ) internal {
        insurancePool.updateWhenExpire(_premium, _payoff, _userAddress);
        policyList[_policyId].status = PolicyStatus.EXPIRED;
        emit PolicyExpired(_policyId, _userAddress);
    }

    /**
     * @notice Update the policy when it is claimed
     * @param _premium Premium of the policy sold
     * @param _payoff Payoff of the policy sold
     * @param _userAddress User's address
     * @param _policyId The unique policy ID
     */
    function _policyClaimed(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        uint256 _policyId
    ) internal {
        insurancePool.payClaim(_premium, MAX_PAYOFF, _payoff, _userAddress);
        policyList[_policyId].status = PolicyStatus.CLAIMED;
        emit PolicyClaimed(_policyId, _userAddress);
    }

    /**
     * @notice The payoff formula
     * @param _delay Delay in minutes
     * @return the final payoff volume
     */
    function calcPayoff(uint256 _delay) internal view returns (uint256) {
        uint256 payoff = 0;

        // payoff model 1 - linear
        if (_delay <= DELAY_THRESHOLD_MIN) {
            payoff = 0;
        } else if (
            _delay > DELAY_THRESHOLD_MIN && _delay <= DELAY_THRESHOLD_MAX
        ) {
            payoff = (_delay * _delay) / 480;
        } else if (_delay > DELAY_THRESHOLD_MAX) {
            payoff = MAX_PAYOFF;
        }

        payoff = payoff * 1e18;
        return payoff;
    }

    /**
     * @notice Check whether the signature is valid
     * @param signature 65 byte array: [[v (1)], [r (32)], [s (32)]]
     * @param _flightNumber Flight number
     * @param _address userAddress
     * @param _premium Premium of the policy
     * @param _deadline Deadline of the application
     */
    function _checkSignature(
        bytes calldata signature,
        string memory _flightNumber,
        address _address,
        uint256 _premium,
        uint256 _deadline
    ) internal view {
        sigManager.checkSignature(
            signature,
            _flightNumber,
            _address,
            _premium,
            _deadline
        );
    }
}
