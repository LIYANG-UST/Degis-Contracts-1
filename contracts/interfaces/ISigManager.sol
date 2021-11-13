// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISigManager {
    event SignerAdded(address indexed _newSigner);
    event SignerRemoved(address indexed _oldSigner);

    function addSigner(address) external;

    function removeSigner(address) external;

    function isValidSigner(address) external returns (bool);
}
