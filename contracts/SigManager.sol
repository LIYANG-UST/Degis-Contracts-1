// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/ISigManager.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

/**
 * @title  Signature Manager
 * @notice Signature is used when submitting new applications.
 *         The premium should be decided by the pricing model and be signed by a private key.
 *         Other submission will not be accepted.
 *         Please keep the signer key safe.
 */
contract SigManager is ISigManager {
    using ECDSA for bytes32;

    address public owner;

    mapping(address => bool) _isValidSigner;

    bytes32 internal _SUBMIT_APPLICATION_TYPEHASH;
    bytes32 internal _SUBMIT_CLAIM_TYPEHASH;

    /**
     *
     */
    constructor() {
        owner = msg.sender;

        _SUBMIT_APPLICATION_TYPEHASH = keccak256(
            "DegisNewApplication(uint256 premium,uint256 payoff)"
        );
        _SUBMIT_CLAIM_TYPEHASH = keccak256(
            "DegisSubmitClaim(uint256 policyOrder,uint256 premium,uint256 payoff)"
        );
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner can call this function");
        _;
    }

    modifier notZeroAddress() {
        require(msg.sender != address(0), "can not use zero address");
        _;
    }

    /**
     * @notice Add a signer into valid signer list
     * @param _newSigner The new signer address
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
     * @param _oldSigner The old signer address to be removed
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

    /**
     * @notice Check whether the address is a valid signer
     * @param _address The input address
     * @return isValidSigner Whether this address is
     */
    function isValidSigner(address _address) public view returns (bool) {
        return _isValidSigner[_address];
    }

    /**
     * @notice Check signature when buying a new policy (avoid arbitrary premium amount)
     * @param signature 65 byte array: [[v (1)], [r (32)], [s (32)]]
     * @param _flightNumber Flight number
     * @param _userAddress User address
     * @param _premium Policy premium
     * @param _deadline Deadline of a policy
     */
    function checkSignature(
        bytes calldata signature,
        string memory _flightNumber,
        address _userAddress,
        uint256 _premium,
        uint256 _deadline
    ) external view {
        bytes32 hashData = keccak256(
            abi.encodePacked(
                _SUBMIT_CLAIM_TYPEHASH,
                _flightNumber,
                _userAddress,
                _premium,
                _deadline
            )
        );
        address signer = hashData.toEthSignedMessageHash().recover(signature);
        require(
            _isValidSigner[signer],
            "Can only submitted by authorized signer"
        );
    }
}
