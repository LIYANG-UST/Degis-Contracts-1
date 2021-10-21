// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**@title  Degis Token
 * @notice DegisToken has an owner, a minter and a burner.
 *         When lauched on mainnet, the owner may be removed.
 *         By default, the owner & minter account will be the one that deploys the contract.
 *         The minter may later be passed to InsurancePool.
 *         The burner may later be passed to EmergencyPool.
 */
contract DegisToken is ERC20 {
    address public minter;
    address public burner;
    address public owner;

    event MinterChanged(address indexed _oldMinter, address indexed _newMinter);
    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    event BurnerChanged(address indexed _oldBurner, address indexed _newBurner);
    event ReleaseOwnership(address indexed _oldOwner);

    /**
     * @notice Use ERC20 constructor and set the owner, minter and burner
     */
    constructor() ERC20("DegisToken", "DEGIS") {
        minter = msg.sender;
        owner = msg.sender;
        burner = msg.sender;
    }

    /**
     * @notice Pass the minter role to a new address, only the owner can change the minter !!!
     * @param _newMinter: New minter's address
     * @return Whether the minter has been changed
     */
    function passMinterRole(address _newMinter) public returns (bool) {
        require(
            msg.sender == owner,
            "Error! only the owner can change the minter"
        );
        minter = _newMinter;

        emit MinterChanged(msg.sender, _newMinter);
        return true;
    }

    /**
     * @notice Pass the owner role to a new address, only the owner can change the owner !!!
     * @param _newOwner: New owner's address
     * @return Whether the owner has been changed
     */
    function passOwnership(address _newOwner) public returns (bool) {
        require(
            msg.sender == owner,
            "Error! only the owner can change the owner"
        );
        owner = _newOwner;

        emit OwnerChanged(msg.sender, _newOwner);
        return true;
    }

    /**
     * @notice Pass the owner role to a new address, only the owner can change the owner !!!
     * @param _newBurner: New burner's address
     * @return Whether the burner has been changed
     */
    function passBurnerRole(address _newBurner) public returns (bool) {
        require(
            msg.sender == owner,
            "Error! only the owner can change the owner"
        );
        burner = _newBurner;

        emit BurnerChanged(msg.sender, _newBurner);
        return true;
    }

    /**
     * @notice Release the ownership to zero address, can never get back !!!
     * @return Whether the ownership has been released
     */
    function releaseOwnership() public returns (bool) {
        require(
            msg.sender == owner,
            "Error! only the owner can release ownership"
        );
        owner = address(0);

        emit ReleaseOwnership(msg.sender);
        return true;
    }

    /**
     * @notice Mint tokens
     * @param _account: Receiver's address
     * @param _amount: Amount to be minted
     */
    function mint(address _account, uint256 _amount) public {
        require(msg.sender == minter, "Error! Msg.sender must be the minter");

        _mint(_account, _amount); // ERC20 method with an event
    }

    /**
     * @notice Burn tokens
     * @param _account: address
     * @param _amount: amount to be burned
     */
    function burn(address _account, uint256 _amount) public {
        require(msg.sender == burner, "Error! Msg.sender must be the burner");
        _burn(_account, _amount);
    }
}
