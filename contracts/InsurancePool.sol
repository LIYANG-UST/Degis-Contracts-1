// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DegisToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "./libraries/Policy.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// import "./libraries/FixedMath.sol";

//import "@openzeppelin/contracts/access/Ownable.sol";

contract InsurancePool {
    using FixedPoint for *;
    using SafeMath for *;
    using SafeERC20 for IERC20;

    // the onwer address of this contract
    address public owner;
    address public policyFlow;

    // UserInfo.rewardDebt: the pending reward(degis token)
    struct UserInfo {
        uint256 rewardDebt;
        uint256 assetBalance; // the amount of a user's staking in the pool
        uint256 freeBalance; // the unlocked amount of a user's staking
        uint256 unstakePointer;
    }
    mapping(address => UserInfo) userInfo;

    DegisToken public immutable DEGIS; // the contract instance of degis token

    IERC20 public USDC_TOKEN;

    // current total staking balance of the pool
    uint256 currentStakingBalance;

    // real staking balance = current staking balance - sum(unstake request)
    uint256 realStakingBalance;

    // locked balance is for potiential payoff
    uint256 lockedBalance;

    // locked relation = locked balance / currentStakingBalance
    FixedPoint.uq112x112 lockedRatio;

    // available capacity is the current available asset balance
    uint256 availableCapacity;

    // premiums have been paid but the policies haven't expired
    uint256 activePremiums;

    // rewardCollected is total income from premium
    uint256 rewardCollected;

    // collateral factor = asset / max risk exposure, initially need to be >100%
    FixedPoint.uq112x112 public collateralFactor;

    // poolInfo: the information about this pool
    struct PoolInfo {
        string poolName;
        uint256 poolId;
        uint256 accDegisPerShare;
        uint256 lastRewardBlock;
        uint256 degisPerBlock;
    }

    PoolInfo poolInfo;

    /**
     * @notice status of every unstake request
     */
    struct UnstakeRequest {
        uint256 pendingAmount;
        uint256 fulfilledAmount;
        bool isPaidOut; // if this request has been paid out
    }

    mapping(address => UnstakeRequest[]) private unstakeRequests;

    // list of all unstake users
    address[] private unstakeQueue;

    // current pointer of the unstake request queue
    uint256 private unstakePointer;

    /**
     * @notice status of every premium
     */
    struct Premium {
        uint256 expiryDate;
        address buyerAddress;
        bool isClaimed;
    }

    Premium[] private premiums;
    // Policy[] private policyList;

    event Stake(address indexed userAddress, uint256 amount);
    event Unstake(address indexed userAddress, uint256 amount);
    event ChangeCollateralFactor(address indexed onwerAddress, uint256 factor);
    event BuyNewPolicy(address userAddress, uint256 premium, uint256 payout);

    /**
     * @notice constructor function
     * @param _factor: initial collateral factor
     * @param _degis: address of the degis token
     * @param _usdcAddress: address of USDC
     */
    constructor(
        uint256 _factor,
        DegisToken _degis,
        address _usdcAddress,
        uint256 _degisPerBlock
    ) {
        owner = msg.sender;
        collateralFactor = calcFactor(_factor, 100);
        lockedRatio = calcFactor(0, 1);
        DEGIS = _degis;
        USDC_TOKEN = IERC20(_usdcAddress);
        poolInfo = PoolInfo(
            "insurancepool",
            0,
            0,
            block.number,
            _degisPerBlock
        );
    }

    /**
     * @notice only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner can call this function");
        _;
    }
    /**
     * @notice only the policyFlow contract can call some functions
     */
    modifier onlyPolicyFlow() {
        require(
            msg.sender == policyFlow,
            "only called by the policy flow contract"
        );
        _;
    }

    /**
     * @notice set the address of policyFlow
     */
    function setPolicyFlow(address _policyFlowAddress) public onlyOwner {
        policyFlow = _policyFlowAddress;
    }

    //calcFactor function is moved to library/FixedMath.sol
    /**
     * @notice calculate the fixed point form of collateral factor
     * @param _numerator: the factor input
     * @param _denominator: 100, the divider
     */
    function calcFactor(uint256 _numerator, uint256 _denominator)
        public
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        return FixedPoint.fraction(_numerator, _denominator);
    }

    /**
     * @notice view how many assets are locked in the pool currently
     */
    function getTotalLocked() public view returns (uint256) {
        return lockedBalance;
    }

    /**
     * @notice view the pool info (only for test, delete when mainnet)
     */
    function getPoolInfo() public view returns (string memory) {
        string memory name = poolInfo.poolName;
        return name;
    }

    // View function to see pending DEGIS on frontend.
    function pendingDegis(address _userAddress)
        external
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_userAddress];
        uint256 accDegisPerShare = poolInfo.accDegisPerShare;

        if (block.number > poolInfo.lastRewardBlock) {
            uint256 blocks = block.number - poolInfo.lastRewardBlock;
            uint256 degisReward = blocks.mul(poolInfo.degisPerBlock);

            accDegisPerShare = accDegisPerShare.add(degisReward).mul(1e18).div(
                currentStakingBalance
            );
        }
        return
            user.assetBalance.mul(accDegisPerShare).div(1e18).sub(
                user.rewardDebt
            );
    }

    /**
     * @notice view the pool's total available capacity
     */
    function getAvailableCapacity() public view returns (uint256) {
        return availableCapacity;
    }

    /**
     * @notice get a user's stake amount in the pool
     * @param _userAddress: the user's address
     */
    function getStakeAmount(address _userAddress)
        public
        view
        returns (uint256)
    {
        return (userInfo[_userAddress].assetBalance);
    }

    /**
     * @notice get the balance that the pool can unlock(maximum)
     * @return the amount that the pool can unlock
     */
    function getPoolUnlocked() public view returns (uint256) {
        return currentStakingBalance - lockedBalance;
    }

    /**
     * @notice get the balance that one user(LP) can unlock(maximum)
     * @param _userAddress: user's address
     * @return the amount that the user can unlock
     */
    function getUnlockedfor(address _userAddress)
        public
        view
        returns (uint256)
    {
        uint256 user_balance = userInfo[_userAddress].assetBalance;
        uint256 _locked_user_balance = lockedRatio
            .mul(user_balance)
            .decode144();
        return user_balance - _locked_user_balance;
    }

    /**
     * @notice get the user's locked balance
     * @param _userAddress: user's address
     * @return _amount: the user's locked amount
     */
    function getLockedfor(address _userAddress) public view returns (uint256) {
        uint256 user_balance = userInfo[_userAddress].assetBalance;
        return lockedRatio.mul(user_balance).decode144();
    }

    /**
     * @notice change the collateral factor(only by the owner)
     * @param _factor: the new collateral factor
     */
    function setCollateralFactor(uint256 _factor) public onlyOwner {
        collateralFactor = FixedPoint.uq112x112(uint224(_factor));
        emit ChangeCollateralFactor(owner, _factor);
    }

    /**
     * @notice check the conditions when receive new buying request
     * @param _payoff: the payoff of the policy to be bought
     */
    modifier checkWhenBuy(uint256 _payoff) {
        require(
            availableCapacity >= _payoff,
            "not sufficient risk capacity for this policy"
        );
        _;
    }

    /**
     * @notice update the pool variables when buying policies
     * @param _premium: the premium of the policy just sold
     * @param _payoff: the payoff of the policy just sold
     */
    function updateWhenBuy(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) external checkWhenBuy(_payoff) returns (bool) {
        lockedBalance += _payoff;
        activePremiums += _premium;
        availableCapacity -= _payoff;
        lockedRatio = FixedPoint.uq112x112(
            uint224(lockedBalance / currentStakingBalance)
        );

        emit BuyNewPolicy(_userAddress, _premium, _payoff);
        return true;
    }

    /**
     * @notice stake: a user(LP) want to stake some amount of asset
     * @param _userAddress: user's address
     * @param _amount: the amount that the user want to stake
     */
    function stake(address _userAddress, uint256 _amount) public {
        UserInfo storage user = userInfo[_userAddress];
        if (user.assetBalance > 0) {
            uint256 pending = user
                .assetBalance
                .mul(poolInfo.accDegisPerShare)
                .div(1e18)
                .sub(user.rewardDebt);
            safeDegisTransfer(msg.sender, pending);
            poolInfo.lastRewardBlock = block.number;
        }
        user.rewardDebt = user.assetBalance.mul(poolInfo.accDegisPerShare).div(
            1e18
        );

        _deposit(_userAddress, _amount);
        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice unstake: a user want to unstake some amount
     * @param _userAddress: user's address
     * @param _amount: the amount that the user want to unstake
     */
    function unstake(address _userAddress, uint256 _amount) public {
        require(
            _amount < userInfo[_userAddress].assetBalance,
            "not enough balance to be unlocked"
        );

        // uint256 unlocked = getUnlockedfor(_userAddress);
        uint256 unlocked = getPoolUnlocked();
        uint256 unstakeAmount = _amount;

        if (_amount > unlocked) {
            uint256 remainingURequest = _amount - unlocked;
            uint256 pointer = userInfo[_userAddress].unstakePointer;
            unstakeRequests[_userAddress].push(
                UnstakeRequest(remainingURequest, 0, false)
            );
            unstakeQueue.push(_userAddress);
            unstakeAmount = unlocked;
        }

        UserInfo storage user = userInfo[_userAddress];
        if (user.assetBalance > 0) {
            uint256 pending = user
                .assetBalance
                .mul(poolInfo.accDegisPerShare)
                .div(1e18)
                .sub(user.rewardDebt);
            safeDegisTransfer(msg.sender, pending);
            poolInfo.lastRewardBlock = block.number;
        }

        user.rewardDebt = user.assetBalance.mul(poolInfo.accDegisPerShare).div(
            1e18
        );

        _withdraw(_userAddress, unstakeAmount);
    }

    /**
     * @notice finish the deposit process
     * @param _userAddress: address of the user who deposits
     * @param _amount: the amount he deposits
     */
    function _deposit(address _userAddress, uint256 _amount) internal {
        currentStakingBalance += _amount;
        realStakingBalance += _amount;
        availableCapacity += _amount;
        userInfo[_userAddress].assetBalance += _amount;
        userInfo[_userAddress].freeBalance += _amount;
        lockedRatio = FixedPoint.uq112x112(
            uint224(lockedBalance / currentStakingBalance)
        );

        USDC_TOKEN.safeTransferFrom(_userAddress, address(this), _amount);
        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice _withdraw: finish the withdraw action, only when meeting the conditions
     * @param _userAddress: address of the user who withdraws
     * @param _amount: the amount he withdraws
     */
    function _withdraw(address _userAddress, uint256 _amount) internal {
        currentStakingBalance -= _amount;
        realStakingBalance -= _amount;
        availableCapacity -= _amount;
        userInfo[_userAddress].assetBalance -= _amount;
        userInfo[_userAddress].freeBalance -= _amount;
        lockedRatio = FixedPoint.uq112x112(
            uint224(lockedBalance / currentStakingBalance)
        );
        //加入给用户转账的代码
        // 使用其他ERC20 代币 usdc/dai

        USDC_TOKEN.safeTransfer(_userAddress, _amount);
        emit Unstake(_userAddress, _amount);
    }

    /**
     * @notice update the status when a policy expires
     * @param _premium: the policy's premium
     * @param _payoff: the policy's payoff
     */
    function updateWhenExpire(uint256 _premium, uint256 _payoff)
        public
        onlyPolicyFlow
    {
        activePremiums -= _premium;
        lockedBalance -= _payoff;
        availableCapacity += _payoff;
        rewardCollected += _premium;

        uint256 remainingPayoff = _payoff;
        uint256 pendingAmount;
        for (uint256 i = unstakeQueue.length - 1; i >= 0; i -= 1) {
            if (remainingPayoff >= 0) {
                address pendingUser = unstakeQueue[i];
                for (
                    uint256 j = 0;
                    j < unstakeRequests[pendingUser].length;
                    j++
                ) {
                    pendingAmount = unstakeRequests[pendingUser][j]
                        .pendingAmount;
                    if (remainingPayoff > pendingAmount) {
                        remainingPayoff -= pendingAmount;
                        unstakeRequests[pendingUser].pop();

                        USDC_TOKEN.safeTransferFrom(
                            address(this),
                            pendingUser,
                            pendingAmount
                        );
                    } else {
                        unstakeRequests[pendingUser][j]
                            .pendingAmount -= pendingAmount;
                        remainingPayoff = 0;
                        break;
                    }
                }
            } else break;
        }
    }

    function payClaim(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) public {
        lockedBalance -= _payoff;
        currentStakingBalance -= _payoff;
        realStakingBalance -= _payoff;
        activePremiums -= _premium;

        USDC_TOKEN.safeTransferFrom(address(this), _userAddress, _payoff);
    }

    function recievePremium(uint256 _premium) public {
        activePremiums += _premium;
    }

    /**
     * @notice revert the last unstake request for a user
     * @param _userAddress: user's address
     */
    function revertUnstakeRequest(address _userAddress) public {
        UnstakeRequest[] storage userRequests = unstakeRequests[_userAddress];
        require(
            userRequests.length > 0,
            "this user has no pending unstake request"
        );

        uint256 index = userRequests.length - 1;
        uint256 remainingRequest = userRequests[index].pendingAmount -
            userRequests[index].fulfilledAmount;

        realStakingBalance += remainingRequest;
        userInfo[_userAddress].freeBalance += remainingRequest;

        removeOneRequest(_userAddress);
    }

    /**
     * @notice revert all unstake requests for a user
     * @param _userAddress: user's address
     */
    function revertAllUnstakeRequest(address _userAddress) public {
        UnstakeRequest[] storage userRequests = unstakeRequests[_userAddress];
        require(
            userRequests.length > 0,
            "this user has no pending unstake request"
        );
        removeAllRequest(_userAddress);
        delete unstakeRequests[_userAddress];

        uint256 remainingRequest = userInfo[_userAddress].assetBalance -
            userInfo[_userAddress].freeBalance;
        realStakingBalance += remainingRequest;
        userInfo[_userAddress].freeBalance = userInfo[_userAddress]
            .assetBalance;
    }

    /**
     * @notice remove all unstake requests for a user
     * @param _userAddress: user's address
     */
    function removeAllRequest(address _userAddress) internal {
        for (uint256 i = 0; i < unstakeRequests[_userAddress].length; i += 1) {
            removeOneRequest(_userAddress);
        }
    }

    /**
     * @notice remove one(the latest) unstake requests for a user
     * @param _userAddress: user's address
     */
    function removeOneRequest(address _userAddress) internal {
        uint256 index = unstakeQueue.length - 1;

        while (index >= 0) {
            if (unstakeQueue[index] == _userAddress) break;
            index -= 1;
        }

        for (uint256 j = index; j < unstakeQueue.length - 1; j += 1) {
            unstakeQueue[j] = unstakeQueue[j + 1];
        }

        unstakeQueue.pop();
    }

    /**
     * @notice safe degis transfer (if the pool has enough DEGIS token)
     * @param _to: user's address
     * @param _amount: amount
     */
    function safeDegisTransfer(address _to, uint256 _amount) internal {
        uint256 DegisBalance = DEGIS.balanceOf(address(this));
        if (_amount > DegisBalance) {
            DEGIS.transfer(_to, DegisBalance);
        } else {
            DEGIS.transfer(_to, _amount);
        }
    }
}
