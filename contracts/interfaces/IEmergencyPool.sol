// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IEmergencyPool {
    event Deposit(
        address usdAddress,
        address indexed userAddress,
        uint256 amount
    );
    event Withdraw(
        address usdAddress,
        address indexed userAddress,
        uint256 amount
    );

    event OwnershipTransferred(address _newOwner);

    function name() external view returns (string memory);

    function deposit(
        address usdAddress,
        address userAddress,
        uint256 amount
    ) external;

    function emergencyWithdraw(
        address usdAddress,
        address userAddress,
        uint256 amount
    ) external;
}
