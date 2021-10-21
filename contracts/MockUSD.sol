// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSD is ERC20 {
    uint256 public constant MOCK_SUPPLY = 10000e18;

    constructor() ERC20("MOCKUSD", "USDC") {
        // When first deployed, give the owner some coins
        _mint(msg.sender, MOCK_SUPPLY);
    }

    // Everyone can mint, have fun
    function mint(address account, uint256 value) public {
        _mint(account, value);
    }
}
