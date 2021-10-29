// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

contract PurchaseVault {
    address public owner;

    constructor() {
        owner = msg.sender;
    }
}
