// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInsurancePool {
    event Stake(address indexed userAddress, uint256 amount);
    event Unstake(address indexed userAddress, uint256 amount);
    event ChangeCollateralFactor(address indexed onwerAddress, uint256 factor);
    event BuyNewPolicy(
        address indexed userAddress,
        uint256 premium,
        uint256 payout
    );
    event OwnerChanged(address oldOwner, address newOwner);

    function getTotalLocked() external view returns (uint256);

    function getAvailableCapacity() external view returns (uint256);

    function getStakeAmount(address) external view returns (uint256);

    function getPoolInfo() external view returns (string memory);

    function pendingDegis(address) external view returns (uint256);

    function checkCapacity(uint256) external view returns (bool);

    function updateWhenBuy(
        uint256,
        uint256,
        address
    ) external returns (bool);

    function updateWhenExpire(
        uint256,
        uint256,
        address
    ) external;

    function payClaim(
        uint256,
        uint256,
        uint256,
        address
    ) external;
}
