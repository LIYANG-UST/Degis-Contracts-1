// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILPToken is IERC20 {
    /**
     * @dev Pass the minter role.
     */
    function passMinterRole(address) external returns (bool);

    /**
     * @dev Mint some tokens.
     */
    function mint(address, uint256) external;

    /**
     * @dev Burn some tokens.
     */
    function burn(address, uint256) external;

    // Indicate that the minter Changed !!!
    event MinterChanged(address indexed from, address indexed to);
}
