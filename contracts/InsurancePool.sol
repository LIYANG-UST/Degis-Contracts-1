// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DegisToken.sol";
import "./libraries/Queue.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

//import "@openzeppelin/contracts/access/Ownable.sol";

contract InsurancePool {
    using FixedPoint for *;

    // the onwer address of this contract
    address public owner;

    // UserInfo.rewardDebt: the pending reward(degis token)
    struct UserInfo {
        uint256 rewardDebt;
        uint256 assetBalance; // the amount of a user's staking in the pool
        uint256 freeBalance; // the unlocked amount of a user's staking
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
    struct poolInfo {
        string poolName;
        uint256 poolId;
        uint256 degisPerShare;
        uint256 lastRewardBlock;
        uint256 degisPerBlock;
    }

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
    address[] private unstakeUsers;

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

    event Stake(address indexed userAddress, uint256 amount);
    event Unstake(address indexed userAddress, uint256 amount);
    event ChangeCollateralFactor(address indexed onwerAddress, uint256 factor);

    /**
     * @notice constructor function
     * @param _factor: initial collateral factor
     * @param _degis: address of the degis token
     * @param _usdcAddress: address of USDC
     */
    constructor(
        uint256 _factor,
        DegisToken _degis,
        address _usdcAddress
    ) {
        owner = msg.sender;
        collateralFactor = calcFactor(_factor, 100);
        lockedRatio = calcFactor(0, 1);
        DEGIS = _degis;
        USDC_TOKEN = IERC20(_usdcAddress);
    }

    /**
     * @notice only the owner can call some functions
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "only the owner can call this function");
        _;
    }

    /**
     * @notice calculate the fixed point form of collateral factor
     * @param _numerator: the factor input
     * @param _denominator: 100, the divider
     */
    function calcFactor(uint256 _numerator, uint256 _denominator)
        public
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
     * @notice get the balance that one user(LP) can unlock(maximum)
     * @param _userAddress: user's address
     * @return _amount: the amount that the user can unlock
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
    function updateWhenBuy(uint256 _premium, uint256 _payoff)
        external
        checkWhenBuy(_payoff)
    {
        lockedBalance += _payoff;
        activePremiums += _premium;
        availableCapacity -= _payoff;
        lockedRatio = FixedPoint.uq112x112(
            uint224(lockedBalance / currentStakingBalance)
        );
    }

    // @function stake: a user(LP) want to stake some amount of asset
    // @param userAddress: user's address
    // @param amount: the amount that the user want to stake
    function stake(address userAddress, uint256 amount) public {
        _deposit(userAddress, amount);
        emit Stake(userAddress, amount);
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

        uint256 unlocked = getUnlockedfor(_userAddress);
        uint256 unstakeAmount = _amount;

        if (_amount > unlocked) {
            uint256 remainingURequest = _amount - unlocked;

            unstakeRequests[_userAddress].push(
                UnstakeRequest(_amount, 0, false)
            );
            unstakeUsers.push(_userAddress);
            unstakeAmount = unlocked;
        }

        _withdraw(_userAddress, unstakeAmount);
    }

    /**
     * @notice: finish the deposit action
     * @param _userAddress: address of the user who deposits
     * @param _amount: the amount he deposits
     */
    function _deposit(address _userAddress, uint256 _amount) internal {
        currentStakingBalance += _amount;
        realStakingBalance += _amount;
        userInfo[_userAddress].assetBalance += _amount;
        lockedRatio = lockedBalance / currentStakingBalance;
    }

    /**
     * @notice _withdraw: finish the withdraw action, only when meeting the conditions
     * @param _userAddress: address of the user who withdraws
     * @param _amount: the amount he withdraws
     */
    function _withdraw(address _userAddress, uint256 _amount) internal {
        currentStakingBalance -= _amount;
        realStakingBalance -= _amount;
        userInfo[_userAddress].assetBalance -= _amount;
        userInfo[_userAddress].freeBalance -= _amount;
        lockedRatio = lockedBalance / currentStakingBalance;
        //加入给用户转账的代码
        // 使用其他ERC20 代币 usdc/dai
        USDC_TOKEN.transferFrom(address(this), _userAddress, _amount);
        emit Unstake(_userAddress, _amount);
    }

    function updateWhenExpire(uint256 _premium, uint256 _payoff) public {
        activePremiums -= _premium;
        lockedBalance -= _payoff;
        availableCapacity += _payoff;
        rewardCollected += _premium;
    }

    function payClaim(uint256 _payoff) public {
        availableCapacity -= _payoff;
    }

    function recievePremium(uint256 _premium) public {
        activePremiums += _premium;
    }
}
