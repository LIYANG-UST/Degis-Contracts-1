// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title LPToken
 * @notice This is the LP Token for flight delay insurance pool.
 *         When users deposit funds into the pool, they will get the LP Tokens.
 *
 */

contract LPToken is ERC20 {
    address public minter;
    address public owner;

    event MinterChanged(address indexed from, address to);

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner call this function");
        _;
    }

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

    function passMinterRole(address _minter) public onlyOwner returns (bool) {
        minter = _minter;
        emit MinterChanged(msg.sender, _minter);
        return true;
    }
}
