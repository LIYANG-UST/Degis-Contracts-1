// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import ".interfaces/ILPToken.sol";
import ".interfaces/IDegisToken.sol";

contract FarmingPool {
    using SafeERC20 for IERC20;

    uint256 public _nextPoolId; // poolId starts from 1, zero means not in the farm

    struct PoolInfo {
        IERC20 lpToken;
        uint256 degisPerBlock;
        uint256 lastRewardBlock;
        uint256 accDegisPerShare;
    }
    mapping(address => uint256) poolMapping; // lptoken => poolId
    mapping(uint256 => bool) isFarming; // poolId => alreadyFarming
    PoolInfo[] poolList;

    struct UserInfo {
        uint256 rewardDebt; // degis reward debt
        uint256 stakingBalance; // the amount of a user's staking in the pool
    }
    mapping(address => UserInfo) userInfo;

    IDegisToken degis;

    uint256 public startBlock;

    event Stake(address _staker, uint256 _poolId, uint256 _amount);
    event Withdraw(address _staker, uint256 _poolId, uint256 _amount);
    event Harvest(uint256 _poolId, address _to);
    event NewPoolAdded(address _lpToken);

    error AlreadyInPool(address _lpToken);

    constructor(address _degis, uint256 _startBlock) {
        degis = IDegisToken(_degis);
        startBlock = _startBlock;
        _nextPoolId = 1;
    }

    /// @notice Add a new lp to the pool. Can only be called by the owner.
    function add(
        address _lpToken,
        uint256 _degisPerBlock,
        bool _isUpdate
    ) public onlyOwner {
        bool isInPool = _alreadyInPool(_lpToken);

        if (isInPool) {
            revert AlreadyInPool(_lpToken);
        }

        if (_isUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;

        poolList.push(
            PoolInfo({
                lpToken: IERC20(_lpToken),
                degisPerBlock: _degisPerBlock,
                lastRewardBlock: lastRewardBlock,
                accDegisPerShare: 0
            })
        );
        poolMapping[_lpToken] = _nextPoolId;
        isFarming[_nextPoolId] = true;

        _nextPoolId += 1;

        emit NewPoolAdded(_lpToken);
    }

    /**
     * @notice Update the degisPerBlock for a specific pool (set to 0 to stop farming)
     * @param _poolId: Id of the pool
     * @param _degisPerBlock: New reward amount per block
     * @param _withUpdate: Whether update all the pool
     */
    function set(
        uint256 _poolId,
        uint256 _degisPerBlock,
        bool _withUpdate
    ) public onlyOwner {
        require(
            poolList[_poolId].lastRewardBlock != 0,
            "no such pool, your poolId may be wrong"
        );
        if (_withUpdate) {
            massUpdatePools();
        }

        poolInfo[_poolId].degisPerBlock = _degisPerBlock;
    }

    function stake(uint256 _poolId, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];

        updatePool(_poolId);

        if (user.stakingBalance > 0) {
            uint256 pending = user.stakingBalance *
                pool.accDegisPerShare -
                user.rewardDebt;

            safeDegisTransfer(msg.sender, pending);
        }

        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        user.stakingBalance += _amount;
        user.rewardDebt = user.stakingBalance * pool.accDegisPerShare;

        emit Stake(msg.sender, _poolId, _amount);
    }

    function withdraw(uint256 _poolId, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];

        require(user.stakingBalance >= _amount, "not enough balance");

        updatePool(_poolId);

        uint256 pending = user.stakingBalance *
            pool.accDegisPerShare -
            user.rewardDebt;

        safeDegisTransfer(msg.sender, pending);

        user.stakingBalance -= _amount;
        user.rewardDebt = user.stakingBalance * pool.accDegisPerShare;

        pool.lpToken.safeTransfer(address(msg.sender), _amount);

        emit Withdraw(msg.sender, _poolId, _amount);
    }

    function updatePool(uint256 _poolId) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number - pool.lastRewardBlock;
        uint256 degisReward = blocks * pool.degisPerBlock;

        degis.mint(address(this), sushiReward);

        pool.accDegisPerShare += degisReward / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param _poolId The index of the pool. See `poolInfo`.
    /// @param _to Receiver of DEGIS rewards.
    function harvest(uint256 _poolId, address _to) public {
        updatePool(_poolId);
        PoolInfo memory pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[pid][msg.sender];

        uint256 pendingReward = (user.stakingBalance * pool.accDegisPerShare) /
            (1e18) -
            user.rewardDebt;

        // Effects
        user.rewardDebt = user.stakingBalance * pool.accDegisPerShare;

        // Interactions
        if (pendingReward != 0) {
            degis.safeTransfer(_to, pendingDegis);
        }

        emit Harvest(msg.sender, pid, pendingDegis);
    }

    /**
     * @notice Safe degis transfer (check if the pool has enough DEGIS token)
     * @param _to: User's address
     * @param _amount: Amount to transfer
     */
    function safeDegisTransfer(address _to, uint256 _amount) internal {
        uint256 DegisBalance = DEGIS.balanceOf(address(this));
        if (_amount > DegisBalance) {
            DEGIS.transfer(_to, DegisBalance);
        } else {
            DEGIS.transfer(_to, _amount);
        }
    }

    /**
     * @notice Update all farming pools (except for those stopped)
     */
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 poolId = 0; poolId < length; poolId++) {
            if (isFarming[poolId] == false) continue;
            else updatePool(pid);
        }
    }

    /**
     * @notice Check if a lptoken has been added into the pool before
     */
    function _alreadyInPool(address _lpTokenAddress) internal returns (bool) {
        uint256 poolId = poolMapping[_lpTokenAddress];
        // Never been added
        if (poolId == 0) return false;
        else return true;
    }
}
