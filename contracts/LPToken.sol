// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address public minter;
    address public owner;

    event MinterChanged(address indexed from, address to);

    constructor() ERC20("Degis-LPToken", "DLP") {
        owner = msg.sender;
        minter = msg.sender;
    }

    function mint(address account, uint256 value) public {
        require(msg.sender == minter, "Error! Msg.sender must be the minter");
        _mint(account, value);
    }

    function burn(address account, uint256 value) public {
        require(msg.sender == minter, "Error! Msg.sender must be the minter");
        _burn(account, value);
    }

    function passMinterRole(address _minter) public returns (bool) {
        require(
            msg.sender == owner,
            "Error! only the owner can change the minter role"
        );

        minter = _minter;
        emit MinterChanged(msg.sender, _minter);
        return true;
    }
}
