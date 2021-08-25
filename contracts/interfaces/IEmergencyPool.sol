// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEmergencyPool {
    event Deposit(address indexed userAddress, uint256 amount);
    event Withdraw(address indexed userAddress, uint256 amount);

    function deposit(address, uint256) external;

    function emergencyWithdraw(address, uint256) external;
}
