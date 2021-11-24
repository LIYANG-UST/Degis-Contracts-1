// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IFarmingPool {
    event Stake(address _staker, uint256 _poolId, uint256 _amount);
    event Withdraw(address _staker, uint256 _poolId, uint256 _amount);
    event Harvest(
        address _staker,
        address _rewardReceiver,
        uint256 _poolId,
        uint256 _pendingReward
    );
    event NewPoolAdded(address _lpToken);
    event RestartFarmingPool(uint256 _poolId, uint256 _blockNumber);
    event StopFarmingPool(uint256 _poolId, uint256 _blockNumber);

    error AlreadyInPool(address _lpToken);

    function pendingDegis(uint256, address) external returns (uint256);

    function setStartBlock(uint256 _startBlock) external;

    function add(
        address _lpToken,
        uint256 _poolId,
        bool _withUpdate
    ) external;

    function setDegisReward(
        uint256 _poolId,
        uint256 _degisPerBlock,
        bool _withUpdate
    ) external;

    function stake(uint256 _poolId, uint256 _amount) external;

    function withdraw(uint256 _poolId, uint256 _amount) external;
}
