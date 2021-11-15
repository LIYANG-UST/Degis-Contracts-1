// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";
import "./InsurancePoolStore.sol";
import "./interfaces/IDegisToken.sol";
import "./interfaces/ILPToken.sol";
import "./interfaces/IEmergencyPool.sol";
import "./interfaces/IDegisLottery.sol";

contract InsurancePool is InsurancePoolStore {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;
    // ---------------------------------------------------------------------------------------- //
    // *********************************** State Variables ************************************ //
    // ---------------------------------------------------------------------------------------- //
    string public constant name = "Degis FlightDelay InsurancePool";

    address public owner;

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Other Contracts ************************************ //
    // ---------------------------------------------------------------------------------------- //

    IDegisToken public DEGIS;
    IERC20 public USDT;
    IEmergencyPool public emergencyPool;
    ILPToken public DLPToken;
    IDegisLottery public degisLottery;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice constructor function
     * @param _factor: initial collateral factor
     * @param _degis: address of the degis token
     * @param _emergencyPool: address of the emergency pool
     * @param _lptoken: address of LP token
     * @param _usdtAddress: address of USDC
     */
    constructor(
        uint256 _factor,
        address _degis,
        address _emergencyPool,
        address _lptoken,
        address _degisLottery,
        address _usdtAddress
    ) {
        owner = msg.sender;

        collateralFactor = doDiv(_factor, 100);

        lockedRatio = 1e18; // 1e18 = 1

        poolInfo = PoolInfo(
            0, // TOTAL LP
            0, // accPremiumPerShare
            0 // lastRewardCollected
        );

        DEGIS = IDegisToken(_degis);
        USDT = IERC20(_usdtAddress);
        DLPToken = ILPToken(_lptoken);
        emergencyPool = IEmergencyPool(_emergencyPool);
        degisLottery = IDegisLottery(_degisLottery);

        LPValue = 1e18;

        // Initial distribution, 0: LP 1: Emergency 2: Lottery(Staking)
        rewardDistribution[0] = 80;
        rewardDistribution[1] = 10;
        rewardDistribution[2] = 10;

        // Degis compensation when no payoff
        purchaseIncentive = false;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner can call this function");
        _;
    }

    /**
     * @notice Only the policyFlow contract can call some functions
     */
    modifier onlyPolicyFlow() {
        require(
            msg.sender == policyFlow,
            "only the policyFlow contract can call this function"
        );
        _;
    }

    /**
     * @notice The address can not be zero
     */
    modifier notZeroAddress(address _address) {
        require(_address != address(0), "the address can not be zero address");
        _;
    }

    modifier afterFrozenTime(address _userAddress) {
        require(
            block.timestamp >= userInfo[_userAddress].depositTime,
            "Can not withdraw until the fronzen time"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice view the collateral factor
     */
    function getCollateralFactor() public view returns (uint256) {
        return collateralFactor;
    }

    /**
     * @notice view the pending premium amount in frontend
     */
    function pendingPremium(address _userAddress)
        external
        view
        returns (uint256 _pendingPremium)
    {
        UserInfo storage user = userInfo[_userAddress];

        uint256 real_balance = getRealBalance(_userAddress);

        uint256 accPremiumPerShare = poolInfo.accPremiumPerShare;

        _pendingPremium =
            (real_balance * accPremiumPerShare) /
            (1e18) -
            (user.premiumDebt);
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
    function getUnlockedFor(address _userAddress)
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

    /**
     * @notice Open the purchase incentive program
     */
    function openPurchaseIncentive() public onlyOwner {
        require(
            purchaseIncentive == false,
            "the purchase incentive has already turned on"
        );
        purchaseIncentive = true;
        emit PurchaseIncentiveOn(block.timestamp);
    }

    /**
     * @notice Close the purchase incentive program
     */
    function closePurchaseIncentive() public onlyOwner {
        require(
            purchaseIncentive == true,
            "the purchase incentive has already turned off"
        );
        purchaseIncentive = false;
        emit PurchaseIncentiveOff(block.timestamp);
    }

    /**
     * @notice Set a new punish time
     * @param _newFrozenTime: New punish time, in timestamp(s)
     */
    function setFrozenTime(uint256 _newFrozenTime) external onlyOwner {
        frozenTime = _newFrozenTime;
    }

    /**
     * @notice Set the address of policyFlow
     */
    function setPolicyFlow(address _policyFlowAddress) public onlyOwner {
        policyFlow = _policyFlowAddress;
        emit SetPolicyFlow(_policyFlowAddress);
    }

    /**
     * @notice Set the premium reward distribution
     * @param _newDistribution: New distribution [LP, Emergency, Lottery]
     */
    function setIncomeDistribution(uint256[3] memory _newDistribution)
        public
        onlyOwner
    {
        uint256 sum = _newDistribution[0] +
            _newDistribution[1] +
            _newDistribution[2];
        require(sum == 100, "Reward distribution must sum to 100");

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
        notZeroAddress(_newOwner)
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
     * @notice Update the pool's reward status for premium
     *         When to update:
     *              1. RewardCollected changes
     *              2. TotalStakingBalance changes
     */
    function updatePoolReward() internal {
        // Update the accPremiumPerShare status
        uint256 premiumReward = rewardCollected - poolInfo.lastRewardCollected;
        poolInfo.accPremiumPerShare +=
            (premiumReward * (1e18)) /
            (totalStakingBalance);
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
        notZeroAddress(_userAddress)
    {
        require(_amount > 0, "Can not deposit 0");

        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();

        uint256 real_balance = getRealBalance(_userAddress);

        _deposit(_userAddress, _amount);

        real_balance = getRealBalance(_userAddress);

        user.premiumDebt =
            (real_balance * (poolInfo.accPremiumPerShare)) /
            (1e18);

        user.depositTime = block.timestamp;

        poolInfo.lastRewardCollected = rewardCollected;

        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice Unstake from the pool
     * @param _userAddress: User's address
     * @param _amount: The amount that the user want to unstake
     */
    function unstake(address _userAddress, uint256 _amount)
        external
        notZeroAddress(_userAddress)
        afterFrozenTime(_userAddress)
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
            uint256 pending_premium = ((real_balance *
                poolInfo.accPremiumPerShare) / (1e18)) - (user.premiumDebt);
            USDT.safeTransfer(_userAddress, pending_premium);
        }

        _withdraw(_userAddress, unstakeAmount);

        real_balance = getRealBalance(_userAddress);

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
        USDT.safeTransferFrom(_userAddress, address(this), _premium);

        if (purchaseIncentive == true) {
            updatePoolReward();
        }

        emit BuyNewPolicy(_userAddress, _premium, _payoff);
        return true;
    }

    /**
     * @notice Update the status when a policy expires
     * @param _premium: Policy's premium
     * @param _payoff: Policy's payoff
     * @param _userAddress: User's address
     */
    function updateWhenExpire(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) public {
        updatePoolReward();

        if (purchaseIncentive == true) {
            uint256 incentive = 5e18;
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
        USDT.safeTransfer(address(emergencyPool), premiumToEmergency);
        USDT.safeTransfer(address(degisLottery), premiumToLottery);

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

                            USDT.safeTransfer(pendingUser, pendingAmount);
                        } else {
                            unstakeRequests[pendingUser][j]
                                .pendingAmount -= remainingPayoff;
                            unstakeRequests[pendingUser][j]
                                .fulfilledAmount += remainingPayoff;
                            USDT.safeTransfer(pendingUser, remainingPayoff);

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
        uint256 _realPayoff,
        address _userAddress
    ) public notZeroAddress(_userAddress) {
        // Unlock the max payoff volume
        lockedBalance -= _payoff;
        // Count the real payoff volume
        totalStakingBalance -= _realPayoff;
        realStakingBalance -= _realPayoff;
        // Premiums to distribute
        activePremiums -= _premium;

        uint256 premiumToLP = (_premium * doDiv(rewardDistribution[0], 100)) /
            1e18;
        uint256 premiumToLottery = (_premium *
            doDiv(rewardDistribution[1], 100)) / 1e18;
        uint256 premiumToEmergency = (_premium *
            doDiv(rewardDistribution[2], 100)) / 1e18;

        rewardCollected += premiumToLP;
        updatePoolReward();

        // transfer some reward to emergency pool and lottery pool
        USDT.safeTransfer(address(emergencyPool), premiumToEmergency);
        USDT.safeTransfer(address(degisLottery), premiumToLottery);

        uint256 currentLotteryId = degisLottery.viewCurrentLotteryId();
        degisLottery.injectFunds(currentLotteryId, premiumToLottery);

        updateLPValue();
        USDT.safeTransfer(_userAddress, _realPayoff);
    }

    /**
     * @notice harvest your premium reward
     * @param _userAddress: the address of the premium claimer
     */
    function harvestPremium(address _userAddress)
        public
        notZeroAddress(_userAddress)
    {
        UserInfo storage user = userInfo[_userAddress];
        updatePoolReward();

        uint256 real_balance = getRealBalance(_userAddress);

        if (real_balance > 0) {
            uint256 pending = ((real_balance * poolInfo.accPremiumPerShare) /
                (1e18)) - (user.premiumDebt);
            USDT.safeTransfer(_userAddress, pending);
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
        notZeroAddress(_userAddress)
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
        notZeroAddress(_userAddress)
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

        USDT.safeTransferFrom(_userAddress, address(this), _amount);

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

        USDT.safeTransfer(_userAddress, _amount);

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
