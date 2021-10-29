// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";
import "./interfaces/IDegisToken.sol";
import "./interfaces/ILPToken.sol";
import "./interfaces/IEmergencyPool.sol";
import "./interfaces/IDegisLottery.sol";

contract InsurancePool {
    // ---------------------------------------------------------------------------------------- //
    // *********************************** State Variables ************************************ //
    // ---------------------------------------------------------------------------------------- //

    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    address public owner;

    address public policyFlow;

    bool purchaseIncentive;

    struct UserInfo {
        uint256 rewardDebt; // degis reward debt
        uint256 premiumDebt; // premium reward debt
        uint256 assetBalance; // the amount of a user's staking in the pool
        uint256 pendingBalance; // the amount in the unstake queue
    }
    mapping(address => UserInfo) userInfo;

    mapping(address => uint256) buyerDebt;

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Other Contracts ************************************ //
    // ---------------------------------------------------------------------------------------- //

    IDegisToken public DEGIS;
    IERC20 public USDC_TOKEN;
    IEmergencyPool public emergencyPool;
    ILPToken public DLPToken;
    IDegisLottery public degisLottery;

    // ---------------------------------------------------------------------------------------- //
    // ************************************ State Variables *********************************** //
    // ---------------------------------------------------------------------------------------- //

    // 1 LP = LPValue(USD)
    uint256 public LPValue;

    // Total staking balance of the pool
    uint256 public totalStakingBalance;

    // Real staking balance = current staking balance - sum(unstake request in the queue)
    uint256 public realStakingBalance;

    // Locked balance is for potiential payoff
    uint256 public lockedBalance;

    // locked relation = locked balance / totalStakingBalance
    uint256 public lockedRatio; //  1e18 = 1  1e17 = 0.1  1e19 = 10
    uint256 public collateralFactor; //  1e18 = 1  1e17 = 0.1  1e19 = 10

    // Available capacity for taking new
    uint256 public availableCapacity;

    // Premiums have been paid but the policies haven't expired
    uint256 public activePremiums;

    // Total income from premium
    uint256 public rewardCollected;

    // [0]: LP, [1]: Lottery, [2]: Emergency
    uint256[3] public rewardDistribution;

    // Basic information about the pool
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
    event BuyNewPolicy(
        address indexed userAddress,
        uint256 premium,
        uint256 payout
    );
    event OwnerChanged(address oldOwner, address newOwner);
    event ChangeRewardDistribution(
        uint256 _toLP,
        uint256 _toEmergency,
        uint256 _toLottery
    );
    event PurchaseIncentiveOn(uint256 _blocknumber);
    event PurchaseIncentiveOff(uint256 _blocknumber);
    event SendPurchaseIncentive(address _userAddress, uint256 _amount);

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
        address _degis,
        address _emergencyPool,
        address _lptoken,
        address _degisLottery,
        address _usdcAddress,
        uint256 _degisPerBlock
    ) {
        owner = msg.sender;

        collateralFactor = doDiv(_factor, 100);

        lockedRatio = 1e18; // 1e18 = 1

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

        DEGIS = IDegisToken(_degis);
        USDC_TOKEN = IERC20(_usdcAddress);
        DLPToken = ILPToken(_lptoken);
        emergencyPool = IEmergencyPool(_emergencyPool);
        degisLottery = IDegisLottery(_degisLottery);

        LPValue = 1e18;

        // initial distribution
        rewardDistribution[0] = 80;
        rewardDistribution[1] = 10;
        rewardDistribution[2] = 10;

        // If purchaseIncentive is on
        purchaseIncentive = false;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

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
     * @notice the address can not be zero
     */
    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "the address can not be zero address");
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get accumulated degis per share
     * @dev    This amount is not the latest one !!
     */
    function getAccDegisPerShare() public view returns (uint256) {
        return poolInfo.accDegisPerShare;
    }

    /**
     * @notice view the collateral factor
     */
    function getCollateralFactor() public view returns (uint256) {
        return collateralFactor;
    }

    /**
     * @notice view the pending degis amount in frontend
     */
    function pendingDegis(address _userAddress)
        external
        view
        onlyValidAddress(_userAddress)
        returns (uint256)
    {
        if (block.number < poolInfo.lastRewardBlock) return 0;

        UserInfo storage user = userInfo[_userAddress];

        uint256 real_balance = getRealBalance(_userAddress);

        uint256 accDegisPerShare = poolInfo.accDegisPerShare;

        if (real_balance > 0) {
            uint256 blocks = block.number - poolInfo.lastRewardBlock;
            uint256 degisReward = poolInfo.degisPerBlock * blocks;

            accDegisPerShare += (degisReward * 1e18) / totalStakingBalance;
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

        uint256 real_balance = getRealBalance(_userAddress);

        uint256 accPremiumPerShare = poolInfo.accPremiumPerShare;

        if (block.number > poolInfo.lastRewardBlock) {
            uint256 premiumReward = rewardCollected -
                poolInfo.lastRewardCollected;
            accPremiumPerShare +=
                (premiumReward * (1e18)) /
                (totalStakingBalance);
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
     * @notice View the pool's total available capacity
     */
    function getAvailableCapacity() public view returns (uint256) {
        return availableCapacity;
    }

    /**
     * @notice View the pool's total staking balance
     */
    function getTotalStakingBalance() public view returns (uint256) {
        return totalStakingBalance;
    }

    /**
     * @notice Get the real balance: LPValue * LP_Num
     */
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
        return totalStakingBalance - lockedBalance;
    }

    /**
     * @notice Get the balance that one user(LP) can unlock(maximum)
     * @param _userAddress: User's address
     * @return The amount that the user can unlock
     */
    function getUnlockedfor(address _userAddress)
        public
        view
        returns (uint256)
    {
        // uint256 user_balance = userInfo[_userAddress].assetBalance;
        uint256 user_balance = getRealBalance(_userAddress);
        if (availableCapacity >= user_balance) {
            return user_balance;
        } else {
            return availableCapacity;
        }
    }

    /**
     * @notice get the user's locked balance
     * @param _userAddress: user's address
     * @return The user's locked amount
     */
    function getLockedfor(address _userAddress) public view returns (uint256) {
        uint256 user_balance = getRealBalance(_userAddress);
        uint256 locked = (lockedRatio * user_balance) / (1e18);
        return locked;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Owner Functions *********************************** //
    // ---------------------------------------------------------------------------------------- //

    function setPurchaseIncentive(bool _isOn) public onlyOwner {
        if (_isOn == true) {
            require(
                purchaseIncentive == false,
                "the purchaseIncentive is already on"
            );
            purchaseIncentive = _isOn;
            emit PurcahseIncentiveOn(block.timestamp);
        } else if (_isOn == false) {
            purchaseIncentive = _isOn;
            require(
                purchaseIncentive == true,
                "the purchaseIncentive is already off"
            );
            emit PurcahseIncentiveOff(block.timestamp);
        }
    }

    function openPurchaseIncentive(bool _isOn) public onlyOwner {
        if (_isOn = true) {
            purchaseIncentive = _isOn;
            emit PurcahseIncentiveOn(block.timestamp);
        }
    }

    /**
     * @notice Set the address of policyFlow
     */
    function setPolicyFlow(address _policyFlowAddress) public onlyOwner {
        policyFlow = _policyFlowAddress;
        emit SetPolicyFlow(_policyFlowAddress);
    }

    /**
     * @notice Set the reward distribution
     * @param _newDistribution: New distribution [LP, Emergency, Lottery]
     */
    function setRewardDistribution(uint256[3] memory _newDistribution)
        public
        onlyOwner
    {
        uint256 sum = _newDistribution[0] +
            _newDistribution[1] +
            _newDistribution[2];
        require(sum == 100, "reward distribution must sum to 100");

        for (uint256 i = 0; i < 3; i++) {
            rewardDistribution[i] = _newDistribution[i];
        }
        emit ChangeRewardDistribution(
            _newDistribution[0],
            _newDistribution[1],
            _newDistribution[2]
        );
    }

    /**
     * @notice Transfer the ownership to a new owner
     * @param _newOwner: New owner address
     */
    function transferOwnerShip(address _newOwner)
        public
        onlyOwner
        onlyValidAddress(_newOwner)
    {
        owner = _newOwner;
        emit OwnerChanged(owner, _newOwner);
    }

    /**
     * @notice Change the collateral factor
     * @param _factor: The new collateral factor
     */
    function setCollateralFactor(uint256 _factor) public onlyOwner {
        collateralFactor = doDiv(_factor, 100);
        emit ChangeCollateralFactor(owner, _factor);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Update the pool's reward status for degis & premium
     * Every time the asset changes with a call update it
     */
    function updatePoolReward() internal {
        if (block.number < poolInfo.lastRewardBlock) {
            return;
        }

        if (totalStakingBalance == 0) {
            poolInfo.lastRewardBlock = block.number;
            return;
        }

        // Calculate the degis reward for the whole pool and mint those tokens
        uint256 blocks = block.number - poolInfo.lastRewardBlock;
        uint256 degisReward = poolInfo.degisPerBlock * blocks;
        DEGIS.mint(address(this), degisReward);

        // Update the accDegisPerShare status
        poolInfo.accDegisPerShare +=
            (degisReward * (1e18)) /
            (totalStakingBalance);

        // Update the accPremiumPerShare status
        uint256 premiumReward = rewardCollected - poolInfo.lastRewardCollected;
        poolInfo.accPremiumPerShare +=
            (premiumReward * (1e18)) /
            (totalStakingBalance);

        // Update lastRewardBlock
        poolInfo.lastRewardBlock = block.number;
    }

    /**
     * @notice Check the conditions when receive new buying request
     * @param _payoff: Payoff of the policy to be bought
     * @return Whether there is enough capacity in the pool for this payoff
     */
    function checkCapacity(uint256 _payoff) public view returns (bool) {
        if (availableCapacity >= _payoff) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice LPs stake assets into the pool
     * @param _userAddress: User(LP)'s address
     * @param _amount: The amount that the user want to stake
     */
    function stake(address _userAddress, uint256 _amount)
        external
        onlyValidAddress(_userAddress)
    {
        require(_amount > 0, "can not deposit 0");

        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();

        uint256 real_balance = getRealBalance(_userAddress);

        // If this is not the first deposit, give his Degis reward
        if (real_balance > 0) {
            uint256 pending = ((real_balance * poolInfo.accDegisPerShare) /
                (1e18)) - (user.rewardDebt);
            safeDegisTransfer(_userAddress, pending);
        }

        _deposit(_userAddress, _amount);

        real_balance = getRealBalance(_userAddress);
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
    function unstake(address _userAddress, uint256 _amount)
        external
        onlyValidAddress(_userAddress)
    {
        uint256 real_balance = getRealBalance(_userAddress);
        require(
            _amount <= real_balance && _amount > 0,
            "not enough balance to be unlocked or your withdraw amount is 0"
        );

        uint256 unlocked = getPoolUnlocked();
        uint256 unstakeAmount = _amount;

        if (_amount > unlocked) {
            uint256 remainingURequest = _amount - unlocked;
            unstakeRequests[_userAddress].push(
                UnstakeRequest(remainingURequest, 0, false)
            );
            unstakeQueue.push(_userAddress);
            unstakeAmount = unlocked; // only withdraw the unlocked value
            userInfo[_userAddress].pendingBalance += remainingURequest;
        }

        updatePoolReward();
        UserInfo storage user = userInfo[_userAddress];

        if (real_balance > 0) {
            uint256 pending_degis = ((real_balance *
                poolInfo.accDegisPerShare) / (1e18)) - (user.rewardDebt);
            safeDegisTransfer(_userAddress, pending_degis);

            uint256 pending_premium = ((real_balance *
                poolInfo.accPremiumPerShare) / (1e18)) - (user.premiumDebt);
            USDC_TOKEN.safeTransfer(_userAddress, pending_premium);
        }

        _withdraw(_userAddress, unstakeAmount);

        real_balance = getRealBalance(_userAddress);

        user.rewardDebt = (real_balance * (poolInfo.accDegisPerShare)) / (1e18);
        user.premiumDebt =
            (real_balance * (poolInfo.accPremiumPerShare)) /
            (1e18);

        poolInfo.lastRewardCollected = rewardCollected;
    }

    /**
     * @notice Update the pool variables when buying policies
     * @param _premium: the premium of the policy just sold
     * @param _payoff: the payoff of the policy just sold
     * @param _userAddress: the address of the buyer
     */
    function updateWhenBuy(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) external returns (bool) {
        lockedBalance += _payoff;
        activePremiums += _premium;
        availableCapacity -= _payoff;

        lockedRatio = doDiv(lockedBalance, totalStakingBalance);

        // Remember approval
        USDC_TOKEN.safeTransferFrom(_userAddress, address(this), _premium);

        if (purchaseIncentive == true) {
            updatePoolReward();
            buyerDebt[_userAddress] =
                (poolInfo.accDegisPerShare * _premium) /
                1e18;
        }

        emit BuyNewPolicy(_userAddress, _premium, _payoff);
        return true;
    }

    /**
     * @notice update the status when a policy expires
     * @param _premium: the policy's premium
     * @param _payoff: the policy's payoff
     */
    function updateWhenExpire(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) public {
        updatePoolReward();

        if (purchaseIncentive == true) {
            uint256 incentive = ((poolInfo.accDegisPerShare * _premium) /
                1e18) - buyerDebt[_userAddress];
            DEGIS.mint(_userAddress, incentive);
            emit SendPurchaseIncentive(_userAddress, incentive);
        }

        activePremiums -= _premium;
        lockedBalance -= _payoff;
        availableCapacity += _payoff;

        uint256 premiumToLP = (_premium * doDiv(rewardDistribution[0], 100)) /
            1e18;
        uint256 premiumToLottery = (_premium *
            doDiv(rewardDistribution[1], 100)) / 1e18;
        uint256 premiumToEmergency = (_premium *
            doDiv(rewardDistribution[2], 100)) / 1e18;

        rewardCollected += premiumToLP;

        // Transfer some reward to emergency pool and lottery pool
        USDC_TOKEN.safeTransfer(address(emergencyPool), premiumToEmergency);
        USDC_TOKEN.safeTransfer(address(degisLottery), premiumToLottery);

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
     * @notice Pay a claim
     * @param _premium: The policy's premium
     * @param _payoff: The policy's payoff
     * @param _userAddress: Address of the policy claimer
     */
    function payClaim(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) public onlyValidAddress(_userAddress) {
        updatePoolReward();

        lockedBalance -= _payoff;
        totalStakingBalance -= _payoff;
        realStakingBalance -= _payoff;
        activePremiums -= _premium;

        uint256 premiumToLP = (_premium * doDiv(rewardDistribution[0], 100)) /
            1e18;
        uint256 premiumToLottery = (_premium *
            doDiv(rewardDistribution[1], 100)) / 1e18;
        uint256 premiumToEmergency = (_premium *
            doDiv(rewardDistribution[2], 100)) / 1e18;

        rewardCollected += premiumToLP;

        // transfer some reward to emergency pool and lottery pool
        USDC_TOKEN.safeTransfer(address(emergencyPool), premiumToEmergency);
        USDC_TOKEN.safeTransfer(address(degisLottery), premiumToLottery);

        uint256 currentLotteryId = degisLottery.viewCurrentLotteryId();
        degisLottery.injectFunds(currentLotteryId, premiumToLottery);

        updateLPValue();
        USDC_TOKEN.safeTransfer(_userAddress, _payoff);
    }

    /**
     * @notice harvest your degis reward
     * @param _userAddress: the address of the degis claimer
     */
    function harvestDegisReward(address _userAddress)
        public
        onlyValidAddress(_userAddress)
    {
        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();

        uint256 real_balance = getRealBalance(_userAddress);

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
    function harvestPremium(address _userAddress)
        public
        onlyValidAddress(_userAddress)
    {
        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();

        uint256 real_balance = getRealBalance(_userAddress);

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
    function revertUnstakeRequest(address _userAddress)
        public
        onlyValidAddress(_userAddress)
    {
        UnstakeRequest[] storage userRequests = unstakeRequests[_userAddress];
        require(
            userRequests.length > 0,
            "this user has no pending unstake request"
        );

        uint256 index = userRequests.length - 1;
        uint256 remainingRequest = userRequests[index].pendingAmount -
            userRequests[index].fulfilledAmount;

        realStakingBalance += remainingRequest;
        userInfo[_userAddress].pendingBalance -= remainingRequest;

        removeOneRequest(_userAddress);
    }

    /**
     * @notice revert all unstake requests for a user
     * @param _userAddress: user's address
     */
    function revertAllUnstakeRequest(address _userAddress)
        public
        onlyValidAddress(_userAddress)
    {
        UnstakeRequest[] storage userRequests = unstakeRequests[_userAddress];
        require(
            userRequests.length > 0,
            "this user has no pending unstake request"
        );
        removeAllRequest(_userAddress);
        delete unstakeRequests[_userAddress];

        userInfo[_userAddress].assetBalance = getRealBalance(_userAddress);

        uint256 remainingRequest = userInfo[_userAddress].pendingBalance;
        realStakingBalance += remainingRequest;
        userInfo[_userAddress].pendingBalance = 0;
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

    // ---------------------------------------------------------------------------------------- //
    // ********************************** Internal Functions ********************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Finish the deposit process
     * @param _userAddress: Address of the user who deposits
     * @param _amount: Amount he deposits
     */
    function _deposit(address _userAddress, uint256 _amount) internal {
        // Update the pool's status
        totalStakingBalance += _amount;
        realStakingBalance += _amount;
        availableCapacity += _amount;

        lockedRatio = doDiv(lockedBalance, totalStakingBalance);

        USDC_TOKEN.safeTransferFrom(_userAddress, address(this), _amount);

        // LP Token number need to be newly minted
        uint256 lp_num = doDiv(_amount, LPValue);
        DLPToken.mint(_userAddress, lp_num);
        poolInfo.totalLP += lp_num;

        updateLPValue();

        userInfo[_userAddress].assetBalance = getRealBalance(_userAddress);

        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice _withdraw: finish the withdraw action, only when meeting the conditions
     * @param _userAddress: address of the user who withdraws
     * @param _amount: the amount he withdraws
     */
    function _withdraw(address _userAddress, uint256 _amount) internal {
        // Update the pool's status
        totalStakingBalance -= _amount;
        realStakingBalance -= _amount;
        availableCapacity -= _amount;

        lockedRatio = doDiv(lockedBalance, totalStakingBalance);

        USDC_TOKEN.safeTransfer(_userAddress, _amount);

        uint256 lp_num = doDiv(_amount, LPValue);
        DLPToken.burn(_userAddress, lp_num);
        poolInfo.totalLP -= lp_num;
        updateLPValue();

        userInfo[_userAddress].assetBalance = getRealBalance(_userAddress);

        emit Unstake(_userAddress, _amount);
    }

    /**
     * @notice update the value of each lp token
     */
    function updateLPValue() internal {
        uint256 totalLP = poolInfo.totalLP;
        LPValue = doDiv(totalStakingBalance, totalLP);
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

    /**
     * @notice Do division via PRBMath
     * @dev    E.g. doDiv(1, 1) = 1e18  doDiv(1, 10) = 1e17 doDiv(10, 1) = 1e19
     */
    function doDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return PRBMathUD60x18.div(x, y);
    }

    /**
     * @notice Do multiplication via PRBMath
     * @dev    E.g. doMul(1, 1) = 1e18  doMul(2, 5) = 1e19
     */
    function doMul(uint256 x, uint256 y) internal pure returns (uint256) {
        return PRBMathUD60x18.mul(x, y);
    }
}
