// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Based on the interface of the ERC20 standard.
 * Just add some boring functions.
 */
interface IDegisToken is IERC20 {
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function passMinterRole(address) external returns (bool);

    function passOwnership(address) external returns (bool);

    function passBurnerRole(address) external returns (bool);

    function releaseOwnership() external returns (bool);

    function mint(address, uint256) external;

    function burn(address, uint256) external;

    // ---------------------------------------------------------------------------------------- //
    // **************************************** Events **************************************** //
    // ---------------------------------------------------------------------------------------- //

    event MinterChanged(address indexed _oldMinter, address indexed _newMinter);
    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    event BurnerChanged(address indexed _oldBurner, address indexed _newBurner);
    event ReleaseOwnership(address indexed _oldOwner);
}
