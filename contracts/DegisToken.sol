// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DegisToken is ERC20 {
    address public minter;
    event MinterChanged(address indexed from, address to);
    /*
        constructor
    */
    constructor() payable ERC20("Degis", "DEG") {
        minter = msg.sender;
    }

    function passMinterRole(address Degis) public returns (bool) {
        require(msg.sender == minter, "Error! only the owner can change the minter role");
        minter = Degis;

        emit MinterChanged(msg.sender, Degis);
        return true;
    }

    function mint(address account, uint256 amount) public {
        //check if msg.sender have minter role
        require(msg.sender == minter, "Error! Msg.sender must be the minter");

            _mint(account, amount);
        }
}