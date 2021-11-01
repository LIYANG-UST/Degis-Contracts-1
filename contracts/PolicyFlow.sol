// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./libraries/ToStrings.sol";
import "./interfaces/IInsurancePool.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./interfaces/IPolicyToken.sol";
import "./interfaces/IPolicyFlow.sol";
import "./interfaces/IFlightOracle.sol";

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
contract PolicyFlow is ChainlinkClient, IPolicyFlow, ToStrings {
    /// @notice Using some libraries
    using Chainlink for Chainlink.Request;
    using Strings for uint256;
    using ECDSA for bytes32;

    uint256 constant PRODUCT_ID = 0;

    bytes32 internal _SUBMIT_APPLICATION_TYPEHASH;
    bytes32 internal _SUBMIT_CLAIM_TYPEHASH;

    uint256 public oracleResponse; // A test variable to store the oracle address
    uint256 fee;
    string private FLIGHT_STATUS_URL = "http://39.101.132.228:8000/live/";
    address private oracleAddress;
    bytes32 private jobId;

    mapping(bytes32 => uint256) requestList; // requestId => policyId
    mapping(uint256 => uint256) resultList; // policyId => delay result

    address public owner;
    IInsurancePool insurancePool;
    IPolicyToken policyToken;
    IFlightOracle flightOracle;

    // Minimum time before departure for applying
    uint256 public MIN_TIME_BEFORE_DEPARTURE = 24 hours;
    uint256 public MAX_PAYOFF = 180;
    uint256 public DELAY_THRESHOLD_MIN = 30;
    uint256 public DELAY_THRESHOLD_MAX = 240;
    uint256 public Total_Policies;

    // Mappings
    mapping(uint256 => PolicyInfo) policyList; // policyId => policyInfo

    mapping(address => uint256[]) userPolicy; // uint256[]: those totalOrders of a user
    mapping(address => uint256) userPolicyCount; // userAddress => user policy amount

    /// @notice validSigner is our server
    mapping(address => bool) _isValidSigner;

    // Constructor Function
    constructor(
        IInsurancePool _insurancePool,
        IPolicyToken _policyToken,
        address _oracleAddress
    ) {
        // Set owner address
        owner = msg.sender;

        // Set two interfaces' addresses
        insurancePool = _insurancePool;
        policyToken = _policyToken;

        // Set oracle address
        oracleAddress = _oracleAddress;
        jobId = "cef74a7ff7ea4194ab97f00c89abef6b";

        setPublicChainlinkToken();
        fee = 1 * 10**18; // 1 LINK

        // Initialize the count (actually do not need to initialize)
        Total_Policies = 0;

        _SUBMIT_APPLICATION_TYPEHASH = keccak256(
            "DegisNewApplication(uint256 premium,uint256 payoff)"
        );
        _SUBMIT_CLAIM_TYPEHASH = keccak256(
            "DegisSubmitClaim(uint256 policyOrder,uint256 premium,uint256 payoff)"
        );
    }

    // ----------------------------------------------------------------------------------- //
    // ************************************ Modifiers ************************************ //
    // ----------------------------------------------------------------------------------- //

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
     * @notice Check whether the address is a valid signer
     * @param _address: The input address
     * @return True: is a valid signer, can be used to sign the transaction
     *         False: not a valid signer
     */
    function isValidSigner(address _address) public view returns (bool) {
        return _isValidSigner[_address];
    }

    /**
     * @notice Show a user's policies (all)
     * @param _userAddress: User's address (buyer)
     * @return User's policy details in string form
     */
    function viewPolicy(address _userAddress)
        public
        view
        override
        returns (string memory)
    {
        require(userPolicyCount[_userAddress] > 0, "no policy for this user");

        uint256 policyCount = userPolicyCount[_userAddress];
        string memory result = " ";

        for (uint256 i = 0; i < policyCount; i++) {
            uint256 policyId = userPolicy[_userAddress][i];

            string memory isUsed = policyList[policyId].isUsed
                ? "used"
                : "not used";

            string memory result1 = encodePack1(
                i,
                policyList[policyId].flightNumber,
                policyId,
                policyList[policyId].productId,
                policyList[policyId].buyerAddress
            );
            string memory result2 = encodePack2(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].purchaseDate,
                policyList[policyId].departureDate,
                policyList[policyId].landingDate,
                uint256(policyList[policyId].status),
                isUsed,
                policyList[policyId].delayResult
            );

            result = string(abi.encodePacked(result, result1, result2));
        }
        return result;
    }

    /**
     * @notice Get the policyInfo from its count/order
     * @param _policyId: Total count of the policy
     */
    function getPolicyInfoById(uint256 _policyId)
        public
        view
        override
        returns (
            string memory _flightNumber,
            uint256 _productId,
            address _owner,
            uint256 _premium,
            uint256 _payoff,
            uint256 _purchaseDate,
            uint256 _departureDate,
            uint256 _landingDate,
            uint256 _policyStatus
        )
    {
        PolicyInfo memory policy = policyList[_policyId];
        return (
            policy.flightNumber,
            policy.productId,
            policy.buyerAddress,
            policy.premium,
            policy.payoff,
            policy.purchaseDate,
            policy.departureDate,
            policy.landingDate,
            uint256(policy.status)
        );
    }

    /**
     * @notice Get a user's policy amount
     * @param _userAddress: User's address
     * @return User's policy amount
     */
    function getUserPolicyCount(address _userAddress)
        public
        view
        returns (uint256)
    {
        return userPolicyCount[_userAddress];
    }

    /**
     * @notice Get the policy buyer by policyId
     * @param _policyId: Unique policy Id (uint256)
     * @return The buyer of this policy
     */
    function findPolicyBuyerById(uint256 _policyId)
        public
        view
        returns (address)
    {
        return policyList[_policyId].buyerAddress;
    }

    // ----------------------------------------------------------------------------------- //
    // ******************************** Setting Functions ******************************** //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice Change the job Id
     * @param _jobId: New job Id
     */
    function changeJobId(bytes32 _jobId) public onlyOwner {
        jobId = _jobId;
    }

    /**
     * @notice Change the oracle fee
     * @param _fee: new fee
     */
    function changeFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    /**
     * @notice Change the min time before departure
     * @param _newTime: New time set
     */
    function changeMinTimeBeforeDeparture(uint256 _newTime) public onlyOwner {
        MIN_TIME_BEFORE_DEPARTURE = _newTime;
    }

    /**
     * @notice Change the oracle address
     * @param _oracleAddress: New oracle address
     */
    function changeOrcaleAddress(address _oracleAddress) public onlyOwner {
        oracleAddress = _oracleAddress;
    }

    /**
     * @notice Set the new delay threshold
     * @param _thresholdMin: New minimal threshold
     * @param _thresholdMax: New maximum threshold
     */
    function setDelayThreshold(uint256 _thresholdMin, uint256 _thresholdMax)
        public
        onlyOwner
    {
        DELAY_THRESHOLD_MIN = _thresholdMin;
        DELAY_THRESHOLD_MAX = _thresholdMax;
        emit DelayThresholdSet(_thresholdMin, _thresholdMax);
    }

    /**
     * @notice Add a signer into valid signer list
     * @param _newSigner: The new signer address
     */
    function addSigner(address _newSigner) external notZeroAddress onlyOwner {
        require(
            isValidSigner(_newSigner) == false,
            "this address is already a signer"
        );
        _isValidSigner[_newSigner] = true;
        emit SignerAdded(_newSigner);
    }

    /**
     * @notice Remove a signer from the valid signer list
     * @param _oldSigner: The old signer address to be removed
     */
    function removeSigner(address _oldSigner)
        external
        notZeroAddress
        onlyOwner
    {
        require(
            isValidSigner(_oldSigner) == true,
            "this address is not a signer"
        );
        _isValidSigner[_oldSigner] = false;
        emit SignerRemoved(_oldSigner);
    }

    // ----------------------------------------------------------------------------------- //
    // ********************************** Main Functions ********************************* //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice Start a new policy application
     * @param _userAddress: User's address (buyer)
     * @param _productId: ID of the purchased product (0: flightdelay; 1,2,3...: others) (different products)
     * @param _flightNumber: Flight number string (e.g. "AQ1299")
     * @param _premium: Premium of this policy (decimals: 18)
     * @param _departureDate: Departure date of this flight (unix timestamp in s, not ms!)
     * @param _landingDate: Landing date of this flight (uinx timestamp in s, not ms!)
     * @param signature: Use web3.eth.sign(hash(data), privatekey) to generate the signature
     */
    function newApplication(
        address _userAddress,
        uint256 _productId,
        string memory _flightNumber,
        uint256 _premium,
        uint256 _departureDate,
        uint256 _landingDate,
        bytes calldata signature
    ) public override returns (uint256 _policyId) {
        require(
            _productId == PRODUCT_ID,
            "you are calling the wrong product contract"
        );

        require(
            _departureDate >= block.timestamp + MIN_TIME_BEFORE_DEPARTURE,
            "it's too close to the departure time, you cannot buy this policy"
        );

        _checkSignature(
            signature,
            _flightNumber,
            msg.sender,
            _premium,
            MAX_PAYOFF
        );

        // Check the policy with the insurance pool status
        // May be accepted or rejected
        policyCheck(_premium, MAX_PAYOFF, _userAddress, _policyId);

        // Generate the policy
        uint256 currentPolicyId = Total_Policies;
        policyList[currentPolicyId] = PolicyInfo(
            _productId,
            _userAddress,
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

        // Store the policy's total order with userAddress
        userPolicy[_userAddress].push(Total_Policies);
        // Update the user's policy amount
        userPolicyCount[_userAddress] += 1;
        // Update total policies
        Total_Policies += 1;

        emit newPolicyApplication(currentPolicyId, _userAddress);

        return currentPolicyId;
    }

    /** @notice Make a claim request
     *  @param _policyId The total order/id of the policy
     *  @param _flightNumber The flight number
     *  @param _date The flight date
     *  @param _path Which data in json needs to get
     *  @param _forceUpdate Owner can force to update
     */
    function newClaimRequest(
        uint256 _policyId,
        string memory _flightNumber,
        string memory _date,
        string memory _path,
        bool _forceUpdate
    ) public override {
        require(
            block.timestamp >= policyList[_policyId].landingDate,
            "can only claim a policy after its landing"
        );
        require(
            (!policyList[_policyId].isUsed) ||
                (_forceUpdate && (msg.sender == owner)),
            "the policy status has already been settled, or you need to make a force update"
        );
        require(
            keccak256(abi.encodePacked(_flightNumber)) ==
                keccak256(abi.encodePacked(policyList[_policyId].flightNumber)),
            "wrong flight number provided"
        );

        string memory _url = string(
            abi.encodePacked(
                FLIGHT_STATUS_URL,
                _flightNumber,
                "/timestamp=",
                _date
            )
        );

        bytes32 requestId = flightOracle.newOracleRequest(
            oracleAddress,
            jobId,
            fee,
            _url,
            _path,
            1
        );
        requestList[requestId] = _policyId;
        policyList[_policyId].isUsed = true;
    }

    /**
     * @notice Update information when a policy token's ownership has been transferred
     * @dev This function is called by the ERC721 contract of PolicyToken
     * @param _tokenId: Token Id of the policy token
     * @param _oldOwner: The initial owner
     * @param _newOwner: The new owner
     */
    function policyOwnerTransfer(
        uint256 _tokenId,
        address _oldOwner,
        address _newOwner
    ) external override {
        require(
            msg.sender == address(policyToken),
            "only called from the policy token contract"
        );

        uint256 policyId = _tokenId;
        require(
            _oldOwner == policyList[policyId].buyerAddress,
            "the previous owner is wrong"
        );

        policyList[policyId].buyerAddress = _newOwner;
        emit PolicyOwnerTransfer(_tokenId, _newOwner);
    }

    // ----------------------------------------------------------------------------------- //
    // ********************************* Oracle Functions ******************************** //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice Do the final settlement
     * @param _requestId: Chainlink request id
     * @param _result: Delay result (minutes) given by oracle
     */
    function finalSettlement(bytes32 _requestId, uint256 _result)
        public
        override
    {
        oracleResponse = _result;

        uint256 policyId = requestList[_requestId];

        PolicyInfo storage policy = policyList[policyId];
        policy.delayResult = _result;

        uint256 premium = policy.premium;
        uint256 max_payoff = policy.payoff;
        address buyerAddress = policy.buyerAddress;

        if (_result == 0) {
            // 0: on time
            policyExpired(premium, MAX_PAYOFF, buyerAddress, policyId);
        } else if (_result <= DELAY_THRESHOLD_MAX) {
            uint256 real_payoff = calcPayoff(_result);
            policyClaimed(premium, real_payoff, buyerAddress, policyId);
        } else if (_result == 400) {
            // 400: cancelled
            policyClaimed(premium, MAX_PAYOFF, buyerAddress, policyId);
        } else {
            policyExpired(premium, MAX_PAYOFF, buyerAddress, policyId);
        }

        emit FulfilledOracleRequest(policyId, _requestId);
    }

    // ----------------------------------------------------------------------------------- //
    // ******************************** Internal Functions ******************************* //
    // ----------------------------------------------------------------------------------- //

    /**
     * @notice check the policy and then determine whether we can afford it
     * @param _payoff: the payoff of the policy sold
     * @param _userAddress: user's address
     * @param _policyId: the unique policy ID
     */
    function policyCheck(
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
     * @notice Check whether the signature is valid
     * @param signature: 65 byte array: [[v (1)], [r (32)], [s (32)]]
     */
    function _checkSignature(
        bytes calldata signature,
        string memory _flightNumber,
        address _address,
        uint256 _premium,
        uint256 _payoff
    ) internal view {
        bytes32 hashData = keccak256(
            abi.encode(
                _SUBMIT_CLAIM_TYPEHASH,
                _flightNumber,
                _address,
                _premium,
                _payoff
            )
        );
        address signer = hashData.toEthSignedMessageHash().recover(signature);
        require(
            _isValidSigner[signer],
            "Can only submitted by authorized signer"
        );
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
        uint256 _policyId
    ) internal {
        insurancePool.updateWhenExpire(_premium, _payoff, _userAddress);
        policyList[_policyId].status = PolicyStatus.EXPIRED;
        emit PolicyExpired(_policyId, _userAddress);
    }

    /**
     * @notice Update the policy when it is claimed
     * @param _premium: Premium of the policy sold
     * @param _payoff: Payoff of the policy sold
     * @param _userAddress: User's address
     * @param _policyId: The unique policy ID
     */
    function policyClaimed(
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
}
