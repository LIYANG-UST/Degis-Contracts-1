// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBuyerToken is IERC20 {
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    // For public variable isMinter
    function isMinter(address _address) external view returns (bool);

    // For public variable isBurner
    function isBurner(address _address) external view returns (bool);

    /**
     * @notice Mint some buyer tokens
     * @param _account Address to receive the tokens
     * @param _amount Amount to be minted
     */
    function mint(address _account, uint256 _amount) external;

    /**
     * @notice Burn some buyer tokens
     * @param _account Address to burn tokens
     * @param _amount Amount to be burned
     */
    function burn(address _account, uint256 _amount) external;

    /**
     * @notice Add a new minter into the list
     * @param _newMinter Address of the new minter
     */
    function addMinter(address _newMinter) external;

    /**
     * @notice Remove a minter from the list
     * @param _oldMinter Address of the minter to be removed
     */
    function removeMinter(address _oldMinter) external;

    /**
     * @notice Add a new burner into the list
     * @param _newBurner Address of the new burner
     */
    function addBurner(address _newBurner) external;

    /**
     * @notice Remove a minter from the list
     * @param _oldBurner Address of the minter to be removed
     */
    function removeBurner(address _oldBurner) external;

    /**
     * @notice Pass the owner role to a new address, only the owner can change the owner
     * @param _newOwner New owner's address
     */
    function passOwnership(address _newOwner) external;

    /**
     * @notice Release the ownership to zero address, can never get back !
     */
    function releaseOwnership() external;

    // ---------------------------------------------------------------------------------------- //
    // **************************************** Events **************************************** //
    // ---------------------------------------------------------------------------------------- //

    event MinterAdded(address _newMinter);
    event MinterRemoved(address _oldMinter);

    event BurnerAdded(address _newBurner);
    event BurnerRemoved(address _oldBurner);

    event OwnerChanged(address _oldOwner, address _newOwner);
    event OwnershipReleased(address _oldOwner);
}
