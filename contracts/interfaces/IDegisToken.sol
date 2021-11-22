// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/**
 * @dev Based on the interface of the ERC20 standard.
 * Just add some boring functions.
 */
interface IDegisToken is IERC20Permit {
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function cap() external pure returns (uint256);

    function addMinter(address) external;

    function removeMinter(address) external;

    function addBurner(address) external;

    function removeBurner(address) external;

    function passOwnership(address) external;

    function releaseOwnership() external;

    function mint(address, uint256) external;

    function burn(address, uint256) external;

    function closeOwnerMint() external;

    // ---------------------------------------------------------------------------------------- //
    // **************************************** Events **************************************** //
    // ---------------------------------------------------------------------------------------- //

    event MinterAdded(address _newMinter);
    event MinterRemoved(address _oldMinter);

    event BurnerAdded(address _newBurner);
    event BurnerRemoved(address _oldBurner);

    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    event ReleaseOwnership(address indexed _oldOwner);

    event MintByOwner(address _account, uint256 _amount);
    event CloseOwnerMint(address indexed _owner, uint256 _blockNumber);
}
