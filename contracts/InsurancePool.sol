// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DegisToken.sol";
import "./LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";
import "./interfaces/IEmergencyPool.sol";

contract InsurancePool {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    // the onwer address of this contract
    address public owner;

    // the policyflow address, used for access control
    address public policyFlow;

    // *********************************************************************//
    // ****************** Information about each user ****************** //
    struct UserInfo {
        uint256 rewardDebt; // degis reward debt
        uint256 premiumDebt; // premium reward debt
        uint256 assetBalance; // the amount of a user's staking in the pool
        uint256 freeBalance; // the unlocked amount of a user's staking
        // uint256 unstakePointer; // tip: currently not used
    }
    mapping(address => UserInfo) userInfo;

    // ****************** Other contracts that need to interact with ****************** //

    DegisToken public DEGIS; // the contract instance of degis token
    IERC20 public USDC_TOKEN;
    IEmergencyPool public emergencyPool;
    LPToken public DLPToken;

    // ****************** State variables ****************** //

    // 1 lp = LPValue * usd
    uint256 public LPValue;

    // current total staking balance of the pool
    uint256 public currentStakingBalance;

    // real staking balance = current staking balance - sum(unstake request in the queue)
    uint256 public realStakingBalance;

    // locked balance is for potiential payoff
    uint256 public lockedBalance;

    // locked relation = locked balance / currentStakingBalance
    uint256 public PRB_lockedRatio; //  1e18 = 1  1e17 = 0.1  1e19 = 10

    // available capacity is the current available asset balance
    uint256 public availableCapacity;

    // premiums have been paid but the policies haven't expired
    uint256 public activePremiums;

    // rewardCollected is total income from premium
    uint256 public rewardCollected;

    // the information about this pool
    struct PoolInfo {
        string poolName; // insurance pool
        uint256 poolId; // 0
        uint256 totalLP; // total lp amount
        uint256 accDegisPerShare;
        uint256 lastRewardBlock;
        uint256 degisPerBlock;
        uint256 accPremiumPerShare;
        uint256 lastRewardCollected;
    }
    PoolInfo poolInfo;

    //  of every unstake request in the queue
    struct UnstakeRequest {
        uint256 pendingAmount;
        uint256 fulfilledAmount;
        bool isPaidOut; // if this request has been fully paid out // maybe redundant
    }

    // a user's unstake requests
    mapping(address => UnstakeRequest[]) private unstakeRequests;

    // list of all unstake users
    address[] private unstakeQueue;

    // current pointer of the unstake request queue
    // uint256 private unstakePointer;  // currently not used

    event Stake(address indexed userAddress, uint256 amount);
    event Unstake(address indexed userAddress, uint256 amount);
    event ChangeCollateralFactor(address indexed onwerAddress, uint256 factor);
    event SetPolicyFlow(address _policyFlowAddress);
    event BuyNewPolicy(address userAddress, uint256 premium, uint256 payout);
    event OwnerChanged(address oldOwner, address newOwner);

    /**
     * @notice constructor function
     * @param _factor: initial collateral factor
     * @param _degis: address of the degis token
     * @param _emergencyPool: address of the emergency pool
     * @param _lptoken: address of LP token
     * @param _usdcAddress: address of USDC
     * @param _degisPerBlock: degis reward per block
     */
    constructor(
        uint256 _factor,
        DegisToken _degis,
        IEmergencyPool _emergencyPool,
        LPToken _lptoken,
        address _usdcAddress,
        uint256 _degisPerBlock
    ) {
        owner = msg.sender;
        // currently not used
        collateralFactor = calcFactor(_factor, 100);
        lockedRatio = calcFactor(1, 1);

        PRB_lockedRatio = 1e18; // 1e18 = 1
        DEGIS = _degis;
        USDC_TOKEN = IERC20(_usdcAddress);
        poolInfo = PoolInfo(
            "insurancepool", // pool name
            0, // pool id
            0, // TOTAL LP
            0, // accDegisPerShare
            block.number, // lastRewardBlock
            _degisPerBlock,
            0, // accPremiumPerShare
            0 // lastRewardCollected
        );

        DLPToken = _lptoken;
        LPValue = 1e18;
        emergencyPool = _emergencyPool;
    }

    // ************************************ Modifiers ************************************ //

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

    // ************************************ View Functions ************************************ //

    /**
     * @notice get PRB_lockedRatio of the pool
     */
    function getLockedRatio() public view returns (uint256) {
        return PRB_lockedRatio;
    }

    /**
     * @notice get accumulated degis per share
     */
    function getAccDegisPerShare() public view returns (uint256) {
        return poolInfo.accDegisPerShare;
    }

    /**
     * @notice get the premium reward collected now
     */
    function getRewardCollected() public view returns (uint256) {
        return rewardCollected;
    }

    /**
     * @notice view how many assets are locked in the pool currently
     */
    function getTotalLocked() public view returns (uint256) {
        return lockedBalance;
    }

    /**
     * @notice view the locked ratio
     */
    function getLockedRatio()
        public
        view
        returns (FixedPoint.uq112x112 memory)
    {
        return lockedRatio;
    }

    /**
     * @notice view the collateral factor
     */
    function getCollateralFactor()
        public
        view
        returns (FixedPoint.uq112x112 memory)
    {
        return collateralFactor;
    }

    /**
     * @notice view the pending degis amount in frontend
     */
    function pendingDegis(address _userAddress)
        external
        view
        returns (uint256)
    {
        require(_userAddress != address(0), "cannot be zero address");
        if (block.number < poolInfo.lastRewardBlock) return 0;

        UserInfo storage user = userInfo[_userAddress];
        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        uint256 real_balance = doMul(lp_num, LPValue);

        uint256 accDegisPerShare = poolInfo.accDegisPerShare;

        if (real_balance > 0) {
            uint256 blocks = block.number - poolInfo.lastRewardBlock;
            uint256 degisReward = poolInfo.degisPerBlock * blocks;

            accDegisPerShare += (degisReward * 1e18) / currentStakingBalance;
            uint256 pending = ((real_balance * accDegisPerShare) / 1e18) -
                user.rewardDebt;
            return pending;
        } else {
            return 0;
        }
    }

    /**
     * @notice view the pending premium amount in frontend
     */
    function pendingPremium(address _userAddress)
        external
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_userAddress];
        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        uint256 real_balance = doMul(lp_num, LPValue);

        uint256 accPremiumPerShare = poolInfo.accPremiumPerShare;

        if (block.number > poolInfo.lastRewardBlock) {
            uint256 premiumReward = rewardCollected -
                poolInfo.lastRewardCollected;
            accPremiumPerShare +=
                (premiumReward * (1e18)) /
                (currentStakingBalance);
            return
                ((real_balance * accPremiumPerShare) / (1e18)) -
                (user.premiumDebt);
        } else {
            return 0;
        }
    }

    /**
     * @notice view the pool name (only for test, delete when mainnet)
     */
    function getPoolName() public view returns (string memory) {
        string memory name = poolInfo.poolName;
        return name;
    }

    /**
     * @notice view the pool's total available capacity
     */
    function getAvailableCapacity() public view returns (uint256) {
        return availableCapacity;
    }

    /**
     * @notice view the pool's total available capacity
     */
    function getCurrentStakingBalance() public view returns (uint256) {
        return currentStakingBalance;
    }

    function getRealBalance(address _userAddress)
        public
        view
        returns (uint256)
    {
        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        uint256 real_balance = doMul(lp_num, LPValue);
        return real_balance;
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
        // uint256 _locked_user_balance = lockedRatio
        //     .mul(user_balance)
        //     .decode144();
        // uint256 _locked_user_balance = doMul(user_balance, PRB-Ratio);
        // return user_balance - _locked_user_balance;
        if (availableCapacity >= user_balance) {
            return user_balance;
        } else {
            return availableCapacity;
        }
    }

    /**
     * @notice get the user's locked balance
     * @param _userAddress: user's address
     * @return _amount: the user's locked amount
     */
    function getLockedfor(address _userAddress) public view returns (uint256) {
        uint256 user_balance = userInfo[_userAddress].assetBalance;
        return uint256(lockedRatio.mul(user_balance).decode144());
    }

    // ************************************ Helper Functions ************************************ //

    /**
     * @notice set the address of policyFlow
     */
    function setPolicyFlow(address _policyFlowAddress) public onlyOwner {
        policyFlow = _policyFlowAddress;
        emit SetPolicyFlow(_policyFlowAddress);
    }

    /**
     * @notice transfer the ownership to a new owner
     */
    function transferOwnerShip(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "owner cannot be zero address");
        emit OwnerChanged(owner, _newOwner);
        owner = _newOwner;
    }

    /**
     * @notice do division via PRBMath
     */
    function doDiv(uint256 x, uint256 y) public pure returns (uint256 result) {
        result = PRBMathUD60x18.div(x, y);
    }

    /**
     * @notice do multiplication via PRBMath
     */
    function doMul(uint256 x, uint256 y) public pure returns (uint256 result) {
        result = PRBMathUD60x18.mul(x, y);
    }

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
     * @notice change the collateral factor(only by the owner)
     * @param _factor: the new collateral factor
     */
    function setCollateralFactor(uint256 _factor) public onlyOwner {
        // collateralFactor = FixedPoint.uq112x112(uint224(_factor));
        collateralFactor = FixedPoint.fraction(_factor, 100);
        emit ChangeCollateralFactor(owner, _factor);
    }

    // ************************************ Main Functions ************************************ //

    /**
     * @notice update the pool's reward status for degis & premium
     */
    function updatePoolReward() public {
        if (block.number < poolInfo.lastRewardBlock) {
            return;
        }
        if (currentStakingBalance == 0) {
            poolInfo.lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number - poolInfo.lastRewardBlock;
        uint256 degisReward = poolInfo.degisPerBlock * blocks;
        DEGIS.mint(address(this), degisReward);

        poolInfo.accDegisPerShare +=
            (degisReward * (1e18)) /
            (currentStakingBalance);

        uint256 premiumReward = rewardCollected - poolInfo.lastRewardCollected;

        poolInfo.accPremiumPerShare +=
            (premiumReward * (1e18)) /
            (currentStakingBalance);

        poolInfo.lastRewardBlock = block.number;
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
     * @param _userAddress: the address of the buyer
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
        PRB_lockedRatio = doDiv(lockedBalance, currentStakingBalance);

        USDC_TOKEN.safeTransferFrom(_userAddress, address(this), _premium);

        emit BuyNewPolicy(_userAddress, _premium, _payoff);
        return true;
    }

    /**
     * @notice stake: a user(LP) want to stake some amount of asset
     * @param _userAddress: user's address
     * @param _amount: the amount that the user want to stake
     */
    function stake(address _userAddress, uint256 _amount) public {
        require(_userAddress != address(0), "cannot be zero address");
        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();

        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        uint256 real_balance = doMul(lp_num, LPValue);
        // If this is not the first deposit, give his reward
        if (real_balance > 0) {
            uint256 pending = ((real_balance * poolInfo.accDegisPerShare) /
                (1e18)) - (user.rewardDebt);
            safeDegisTransfer(_userAddress, pending);
        }

        _deposit(_userAddress, _amount);

        lp_num = DLPToken.balanceOf(_userAddress);
        real_balance = doMul(lp_num, LPValue);
        user.rewardDebt = (real_balance * (poolInfo.accDegisPerShare)) / (1e18);

        user.premiumDebt =
            (real_balance * (poolInfo.accPremiumPerShare)) /
            (1e18);

        poolInfo.lastRewardCollected = rewardCollected;

        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice unstake: a user want to unstake some amount
     * @param _userAddress: user's address
     * @param _amount: the amount that the user want to unstake
     */
    function unstake(address _userAddress, uint256 _amount) public {
        require(_userAddress != address(0), "cannot be zero address");
        require(
            _amount < userInfo[_userAddress].assetBalance,
            "not enough balance to be unlocked"
        );

        // uint256 unlocked = getUnlockedfor(_userAddress);
        uint256 unlocked = getPoolUnlocked();
        uint256 unstakeAmount = _amount;

        if (_amount > unlocked) {
            uint256 remainingURequest = _amount - unlocked;
            // uint256 pointer = userInfo[_userAddress].unstakePointer;
            unstakeRequests[_userAddress].push(
                UnstakeRequest(remainingURequest, 0, false)
            );
            unstakeQueue.push(_userAddress);
            unstakeAmount = unlocked;
        }

        updatePoolReward();
        UserInfo storage user = userInfo[_userAddress];
        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        uint256 real_balance = doMul(lp_num, LPValue);

        if (real_balance > 0) {
            uint256 pending_degis = ((real_balance *
                poolInfo.accDegisPerShare) / (1e18)) - (user.rewardDebt);
            safeDegisTransfer(msg.sender, pending_degis);

            uint256 pending_premium = ((real_balance *
                poolInfo.accPremiumPerShare) / (1e18)) - (user.premiumDebt);
            USDC_TOKEN.safeTransfer(msg.sender, pending_premium);
        }

        _withdraw(_userAddress, unstakeAmount);

        lp_num = DLPToken.balanceOf(_userAddress);
        real_balance = doMul(lp_num, LPValue);

        user.rewardDebt = (real_balance * (poolInfo.accDegisPerShare)) / (1e18);
        user.premiumDebt =
            (real_balance * (poolInfo.accPremiumPerShare)) /
            (1e18);

        poolInfo.lastRewardCollected = rewardCollected;
    }

    /**
     * @notice finish the deposit process
     * @param _userAddress: address of the user who deposits
     * @param _amount: the amount he deposits
     */
    function _deposit(address _userAddress, uint256 _amount) internal {
        // uint256 real_amount = _amount.div(collateralFactor);
        currentStakingBalance += _amount;
        realStakingBalance += _amount;
        availableCapacity += _amount;

        userInfo[_userAddress].assetBalance += _amount;
        userInfo[_userAddress].freeBalance += _amount;

        lockedRatio = FixedPoint.uq112x112(
            uint224(lockedBalance / currentStakingBalance)
        );

        PRB_lockedRatio = doDiv(lockedBalance, currentStakingBalance);

        USDC_TOKEN.safeTransferFrom(_userAddress, address(this), _amount);

        uint256 lp_num = doDiv(_amount, LPValue);
        DLPToken.mint(_userAddress, lp_num);
        poolInfo.totalLP += lp_num;
        updateLPValue();

        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice update the value of each lp token
     */
    function updateLPValue() internal {
        uint256 totalLP = poolInfo.totalLP;
        LPValue = doDiv(currentStakingBalance, totalLP);
    }

    /**
     * @notice _withdraw: finish the withdraw action, only when meeting the conditions
     * @param _userAddress: address of the user who withdraws
     * @param _amount: the amount he withdraws
     */
    function _withdraw(address _userAddress, uint256 _amount) internal {
        uint256 userLP = DLPToken.balanceOf(_userAddress);
        require(
            doMul(userLP, LPValue) >= _amount,
            "not enough asset to withdraw"
        );

        currentStakingBalance -= _amount;
        realStakingBalance -= _amount;
        availableCapacity -= _amount;

        userInfo[_userAddress].assetBalance -= _amount;
        userInfo[_userAddress].freeBalance -= _amount;

        lockedRatio = FixedPoint.uq112x112(
            uint224(lockedBalance / currentStakingBalance)
        );
        PRB_lockedRatio = doDiv(lockedBalance, currentStakingBalance);
        //加入给用户转账的代码
        // 使用其他ERC20 代币 usdc/dai

        USDC_TOKEN.safeTransfer(_userAddress, _amount);

        uint256 lp_num = doDiv(_amount, LPValue);
        DLPToken.burn(_userAddress, lp_num);
        poolInfo.totalLP -= lp_num;
        updateLPValue();

        emit Unstake(_userAddress, _amount);
    }

    /**
     * @notice update the status when a policy expires
     * @param _premium: the policy's premium
     * @param _payoff: the policy's payoff
     */
    function updateWhenExpire(uint256 _premium, uint256 _payoff) public {
        updatePoolReward();

        activePremiums -= _premium;
        lockedBalance -= _payoff;
        availableCapacity += _payoff;

        uint256 premiumToLP = (_premium * doDiv(9, 10)) / 1e18; // * 9e17
        rewardCollected += premiumToLP;

        // transfer some reward to emergency pool
        USDC_TOKEN.safeTransfer(address(emergencyPool), _premium - premiumToLP);

        uint256 remainingPayoff = _payoff;
        uint256 pendingAmount;
        if (unstakeQueue.length > 0) {
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

                            for (
                                uint256 k = 0;
                                k < unstakeRequests[pendingUser].length - 1;
                                k += 1
                            ) {
                                unstakeRequests[pendingUser][
                                    k
                                ] = unstakeRequests[pendingUser][k + 1];
                            }
                            unstakeRequests[pendingUser].pop();

                            USDC_TOKEN.safeTransfer(pendingUser, pendingAmount);
                        } else {
                            unstakeRequests[pendingUser][j]
                                .pendingAmount -= remainingPayoff;
                            unstakeRequests[pendingUser][j]
                                .fulfilledAmount += remainingPayoff;
                            USDC_TOKEN.safeTransfer(
                                pendingUser,
                                remainingPayoff
                            );

                            remainingPayoff = 0;
                            break;
                        }
                    }
                } else break;
            }
        }
    }

    /**
     * @notice pay a claim
     * @param _premium: the policy's premium
     * @param _payoff: the policy's payoff
     * @param _userAddress: the address of the premium claimer
     */
    function payClaim(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) public {
        require(_userAddress != address(0), "cannot be zero address");

        updatePoolReward();

        lockedBalance -= _payoff;
        currentStakingBalance -= _payoff;
        realStakingBalance -= _payoff;
        activePremiums -= _premium;

        uint256 premiumToLP = (_premium * doDiv(9, 10)) / 1e18; // * 9e17
        rewardCollected += premiumToLP;

        // transfer some reward to emergency pool
        USDC_TOKEN.safeTransfer(address(emergencyPool), _premium - premiumToLP);

        updateLPValue();
        USDC_TOKEN.safeTransfer(_userAddress, _payoff);
    }

    /**
     * @notice harvest your degis reward
     * @param _userAddress: the address of the degis claimer
     */
    function harvestDegisReward(address _userAddress) public {
        require(_userAddress != address(0), "cannot be zero address");

        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();
        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        uint256 real_balance = doMul(lp_num, LPValue);

        if (real_balance > 0) {
            uint256 pending = ((real_balance * poolInfo.accDegisPerShare) /
                (1e18)) - (user.rewardDebt);
            safeDegisTransfer(_userAddress, pending);
        }

        user.rewardDebt = (real_balance * (poolInfo.accDegisPerShare)) / (1e18);
    }

    /**
     * @notice harvest your premium reward
     * @param _userAddress: the address of the premium claimer
     */
    function harvestPremium(address _userAddress) public {
        require(_userAddress != address(0), "cannot be zero address");

        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();
        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        uint256 real_balance = doMul(lp_num, LPValue);

        if (real_balance > 0) {
            uint256 pending = ((real_balance * poolInfo.accPremiumPerShare) /
                (1e18)) - (user.premiumDebt);
            USDC_TOKEN.safeTransfer(_userAddress, pending);
        }
        user.premiumDebt =
            (real_balance * (poolInfo.accPremiumPerShare)) /
            (1e18);

        poolInfo.lastRewardCollected = rewardCollected;
    }

    /**
     * @notice revert the last unstake request for a user
     * @param _userAddress: user's address
     */
    function revertUnstakeRequest(address _userAddress) public {
        require(_userAddress != address(0), "cannot be zero address");

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
        require(_userAddress != address(0), "cannot be zero address");

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
