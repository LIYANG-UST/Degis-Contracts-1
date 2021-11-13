// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IEmergencyPool {
    event Deposit(address indexed userAddress, uint256 amount);
    event Withdraw(address indexed userAddress, uint256 amount);

    function name() external returns (string memory);

    function deposit(address, uint256) external;

    function emergencyWithdraw(address, uint256) external;
}
