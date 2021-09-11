// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev This contract / DegisToken has an owner and a minter.
 * When lauched on mainnet, the owner may be removed ?
 * By default, the owner & minter account will be the one that deploys the contract.
 * This can later be changed with {passMinterRole}.
 */
contract DegisToken is ERC20 {
    // Owner can change the minter
    // Typically the minter will be the "InsurancePool" contract
    // Public addresses, can be checked on Etherscan
    address public minter;
    address public owner;

    // Indicate that the minter Changed !!!
    event MinterChanged(address indexed from, address indexed to);

    /**
     * @notice use ERC20 constructor and set the owner
     */
    constructor() ERC20("DegisToken", "DEGIS") {
        minter = msg.sender;
        owner = msg.sender;
    }

    /**
     * @notice Pass the minter role to a new address, only the owner can change the minter !!!
     * @param _newMinter: new minter's address
     * @return bool: whether the minter has been changed
     */
    function passMinterRole(address _newMinter) public returns (bool) {
        require(
            msg.sender == owner,
            "Error! only the owner can change the minter role"
        );
        minter = _newMinter;

        emit MinterChanged(msg.sender, _newMinter);
        return true;
    }

    /**
     * @notice Mint tokens !!!
     * @param _account: receiver's address
     * @param _amount: amount to be minted
     */
    function mint(address _account, uint256 _amount) public {
        // Check if msg.sender is the minter
        require(msg.sender == minter, "Error! Msg.sender must be the minter");

        _mint(_account, _amount); // ERC20 method with an event
    }
}
