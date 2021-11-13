// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./interfaces/ISigManager.sol";

contract SigManager is ISigManager {
    address public owner;

    mapping(address => bool) _isValidSigner;

    bytes32 internal _SUBMIT_APPLICATION_TYPEHASH;
    bytes32 internal _SUBMIT_CLAIM_TYPEHASH;

    event SignerAdded(address indexed _newSigner);
    event SignerRemoved(address indexed _oldSigner);

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

    /**
     * @notice Check whether the address is a valid signer
     * @param _address: The input address
     * @return True: is a valid signer, can be used to sign the transaction
     *         False: not a valid signer
     */
    function isValidSigner(address _address) public view returns (bool) {
        return _isValidSigner[_address];
    }
}
