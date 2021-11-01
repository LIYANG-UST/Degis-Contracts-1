// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  IPolicyFlow
 * @notice This is the interface of PolicyFlow contract.
 *         Contains some type definations, event list and function declarations.
 */
interface IPolicyFlow {
    /// @notice Enum type of the policy status
    enum PolicyStatus {
        INI,
        SOLD,
        DECLINED,
        EXPIRED,
        CLAIMED
    }

    /// @notice Policy information struct
    struct PolicyInfo {
        uint256 productId; // 0: flight delay 1,2,3: future products
        address buyerAddress; // buyer's address
        uint256 policyId; // total order: 0 - N (unique for each policy)(used to link)
        string flightNumber;
        uint256 premium;
        uint256 payoff;
        uint256 purchaseDate; // Unix timestamp
        uint256 departureDate; // Unix timestamp
        uint256 landingDate;
        PolicyStatus status; // INI, SOLD, DECLINED, EXPIRED, CLAIMED
        // Oracle Related
        bool isUsed; // Whether has call the oracle
        uint256 delayResult; // [400:cancelled] [0: on time] [0 ~ 240: delay time] [404: initial]
    }

    /// @notice Event list
    event newPolicyApplication(uint256 _policyID, address indexed _userAddress);
    event PolicySold(uint256 _policyID, address indexed _userAddress);
    event PolicyDeclined(uint256 _policyID, address indexed _userAddress);
    event PolicyClaimed(uint256 _policyID, address indexed _userAddress);
    event PolicyExpired(uint256 _policyID, address indexed _userAddress);
    event FulfilledOracleRequest(uint256 _policyId, bytes32 _requestId);
    event PolicyOwnerTransfer(uint256 indexed _tokenId, address _newOwner);
    event DelayThresholdSet(uint256 _thresholdMin, uint256 _thresholdMax);
    event SignerAdded(address indexed _newSigner);
    event SignerRemoved(address indexed _oldSigner);

    /// @notice Function declarations

    /// @notice Apply for a new policy
    function newApplication(
        address _userAddress,
        uint256 _productId,
        string memory _flightNumber,
        uint256 _premium,
        uint256 _departureDate,
        uint256 _landingDate,
        bytes calldata signature
    ) external returns (uint256 policyId);

    /// @notice Start a new claim request
    function newClaimRequest(
        uint256 _policyId,
        string memory _flightNumber,
        string memory _date,
        string memory _path,
        bool _forceUpdate
    ) external;

    /// @notice View a user's policy info
    function viewPolicy(address) external view returns (string memory);

    /// @notice Get the policy info by its policyId
    function getPolicyInfoById(uint256)
        external
        view
        returns (
            string memory,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        );

    /// @notice Update when the policy token is transferred to another owner
    function policyOwnerTransfer(
        uint256,
        address,
        address
    ) external;

    /// @notice Do the final settlement when receiving the oracle result
    function finalSettlement(bytes32 _requestId, uint256 _result) external;
}
