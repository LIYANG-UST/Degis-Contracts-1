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
     * @notice Constructor function
     * @param _degisToken Degis token address
     * @param _emergencyPool Emergency pool address
     * @param _lptoken LP token address
     * @param _usdtAddress USDT address
     */
    constructor(
        address _degisToken,
        address _emergencyPool,
        address _lptoken,
        address _degisLottery,
        address _usdtAddress
    ) {
        owner = msg.sender;

        collateralFactor = doDiv(100, 100);

        lockedRatio = 1e18; // 1e18 = 1

        DEGIS = IDegisToken(_degisToken);
        USDT = IERC20(_usdtAddress);
        DLPToken = ILPToken(_lptoken);
        emergencyPool = IEmergencyPool(_emergencyPool);
        degisLottery = IDegisLottery(_degisLottery);

        // Initial LP Value
        LPValue = 1e18;

        // Initial distribution, 0: LP 1: Lottery 2: Emergency
        rewardDistribution[0] = 50;
        rewardDistribution[1] = 40;
        rewardDistribution[2] = 10;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    /**
     * @notice Only the policyFlow contract can call some functions
     */
    modifier onlyPolicyFlow() {
        require(
            msg.sender == policyFlow,
            "Only the policyFlow contract can call this function"
        );
        _;
    }

    /**
     * @notice The address can not be zero
     */
    modifier notZeroAddress(address _address) {
        require(_address != address(0), "Can not be zero address");
        _;
    }

    /**
     * @notice There is a frozen time for unstaking
     */
    modifier afterFrozenTime(address _userAddress) {
        require(
            block.timestamp >= userInfo[_userAddress].depositTime + frozenTime,
            "Can not withdraw until the fronzen time"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the real balance: LPValue * LP_Num
     * @param _userAddress User's address
     * @return user_balance Real balance of this user
     */
    function getUserBalance(address _userAddress)
        public
        view
        returns (uint256 user_balance)
    {
        uint256 lp_num = DLPToken.balanceOf(_userAddress);
        user_balance = doMul(lp_num, LPValue);
    }

    /**
     * @notice Get the balance that the pool can unlock (maximum)
     */
    function getPoolUnlocked() public view returns (uint256) {
        return totalStakingBalance - lockedBalance;
    }

    /**
     * @notice Get the balance that one user(LP) can unlock
     * @param _userAddress User's address
     * @return _unlockedAmount Unlocked amount of the pool
     */
    function getUnlockedFor(address _userAddress)
        public
        view
        returns (uint256 _unlockedAmount)
    {
        uint256 user_balance = getUserBalance(_userAddress);
        _unlockedAmount = availableCapacity >= user_balance
            ? user_balance
            : availableCapacity;
    }

    /**
     * @notice Get the user's locked balance
     * @param _userAddress User's address
     * @return _locked User's locked balance (as the locked ratio)
     */
    function getLockedfor(address _userAddress)
        public
        view
        returns (uint256 _locked)
    {
        uint256 user_balance = getUserBalance(_userAddress);
        _locked = (lockedRatio * user_balance) / (1e18);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Owner Functions *********************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Set the purchase incentive amount
     */
    function setPurchaseIncentive(uint256 _purchaseIncentive)
        external
        onlyOwner
    {
        purchaseIncentiveAmount = _purchaseIncentive;
        emit PurchaseIncentiveChanged(block.timestamp, _purchaseIncentive);
    }

    /**
     * @notice Set a new frozen time
     * @param _newFrozenTime New frozen time, in timestamp(s)
     */
    function setFrozenTime(uint256 _newFrozenTime) external onlyOwner {
        frozenTime = _newFrozenTime;
        emit SetFrozenTime(_newFrozenTime);
    }

    /**
     * @notice Set the address of policyFlow
     */
    function setPolicyFlow(address _policyFlowAddress)
        public
        onlyOwner
        notZeroAddress(_policyFlowAddress)
    {
        policyFlow = _policyFlowAddress;
        emit SetPolicyFlow(_policyFlowAddress);
    }

    /**
     * @notice Set the premium reward distribution
     * @param _newDistribution New distribution [LP, Lottery, Emergency]
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
     * @param _newOwner New owner address
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
     * @param _factor The new collateral factor
     */
    function setCollateralFactor(uint256 _factor) public onlyOwner {
        require(_factor > 0, "Collateral Factor should be larger than 0");
        collateralFactor = doDiv(_factor, 100);
        emit ChangeCollateralFactor(owner, _factor);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Check the conditions when receive new buying request
     * @param _payoff Payoff of the policy to be bought
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
     * @param _userAddress User(LP)'s address
     * @param _amount The amount that the user want to stake
     */
    function stake(address _userAddress, uint256 _amount)
        external
        notZeroAddress(_userAddress)
    {
        require(_amount > 0, "Can not deposit 0");

        _deposit(_userAddress, _amount);

        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice Unstake from the pool (May fail if a claim happens before this operation)
     * @param _userAddress User's address
     * @param _amount The amount that the user want to unstake
     */
    function unstake(address _userAddress, uint256 _amount)
        external
        notZeroAddress(_userAddress)
        afterFrozenTime(_userAddress)
    {
        uint256 user_balance = getUserBalance(_userAddress);
        require(
            _amount <= user_balance && _amount > 0,
            "Not enough balance to be unlocked or your withdraw amount is 0"
        );

        uint256 unlocked = getPoolUnlocked();
        uint256 unstakeAmount = _amount;

        // Will jump this part when the pool has enough liquidity
        if (_amount > unlocked) {
            uint256 remainingURequest = _amount - unlocked;
            unstakeRequests[_userAddress].push(
                UnstakeRequest(remainingURequest, 0, false)
            );
            unstakeQueue.push(_userAddress);
            unstakeAmount = unlocked; // only withdraw the unlocked value
            userInfo[_userAddress].pendingBalance += remainingURequest;
        }

        _withdraw(_userAddress, unstakeAmount);
    }

    /**
     * @notice Unstake the max amount of a user
     * @param _userAddress User's address
     */
    function unstakeMax(address _userAddress)
        external
        notZeroAddress(_userAddress)
        afterFrozenTime(_userAddress)
    {
        uint256 user_balance = getUserBalance(_userAddress);

        uint256 unlocked = getPoolUnlocked();
        uint256 unstakeAmount = user_balance;

        // Will jump this part when the pool has enough liquidity
        if (user_balance > unlocked) {
            uint256 remainingURequest = user_balance - unlocked;
            unstakeRequests[_userAddress].push(
                UnstakeRequest(remainingURequest, 0, false)
            );
            unstakeQueue.push(_userAddress);
            unstakeAmount = unlocked; // only withdraw the unlocked value
            userInfo[_userAddress].pendingBalance += remainingURequest;
        }

        _withdraw(_userAddress, unstakeAmount);
    }

    /**
     * @notice Update the pool variables when buying policies
     * @dev Capacity check is done before calling this function
     * @param _premium Policy's premium
     * @param _payoff Policy's payoff (max payoff)
     * @param _userAddress Address of the buyer
     */
    function updateWhenBuy(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) external onlyPolicyFlow returns (bool) {
        lockedBalance += _payoff;
        activePremiums += _premium;
        availableCapacity -= _payoff;

        lockedRatio = doDiv(lockedBalance, totalStakingBalance);

        // Remember approval
        USDT.safeTransferFrom(_userAddress, address(this), _premium);

        emit BuyNewPolicy(_userAddress, _premium, _payoff);
        return true;
    }

    /**
     * @notice Update the status when a policy expires
     * @param _premium Policy's premium
     * @param _payoff Policy's payoff (max payoff)
     * @param _userAddress User's address
     */
    function updateWhenExpire(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) external onlyPolicyFlow {
        // Give purchase incentive when no payoff
        if (purchaseIncentiveAmount > 0) {
            DEGIS.mint(_userAddress, purchaseIncentiveAmount);
            emit SendPurchaseIncentive(_userAddress, purchaseIncentiveAmount);
        }

        // Update pool status
        activePremiums -= _premium;
        lockedBalance -= _payoff;
        availableCapacity += _payoff;

        // active premium changes, need to update the lp value

        _distributePremium(_premium);

        uint256 remainingPayoff = _payoff;

        if (unstakeQueue.length > 0) {
            _dealUnstakeQueue(remainingPayoff);
        }

        _updateLPValue();
    }

    /**
     * @notice Pay a claim
     * @param _premium Premium of the policy
     * @param _payoff Max payoff of the policy
     * @param _realPayoff Real payoff of the policy
     * @param _userAddress: Address of the policy claimer
     */
    function payClaim(
        uint256 _premium,
        uint256 _payoff,
        uint256 _realPayoff,
        address _userAddress
    ) public onlyPolicyFlow notZeroAddress(_userAddress) {
        // Unlock the max payoff volume
        lockedBalance -= _payoff;
        // Count the real payoff volume
        totalStakingBalance -= _realPayoff;
        realStakingBalance -= _realPayoff;
        // Premiums to distribute
        activePremiums -= _premium;

        _distributePremium(_premium);

        // Pay the claim
        USDT.safeTransfer(_userAddress, _realPayoff);

        _updateLPValue();
    }

    /**
     * @notice revert the last unstake request for a user
     * @param _userAddress user's address
     */
    function revertUnstakeRequest(address _userAddress)
        public
        notZeroAddress(_userAddress)
    {
        require(
            msg.sender == _userAddress || msg.sender == owner,
            "Only the owner or the user himself can revert"
        );

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
     * @param _userAddress user's address
     */
    function revertAllUnstakeRequest(address _userAddress)
        public
        notZeroAddress(_userAddress)
    {
        require(
            msg.sender == _userAddress || msg.sender == owner,
            "Only the owner or the user himself can revert"
        );

        UnstakeRequest[] storage userRequests = unstakeRequests[_userAddress];
        require(
            userRequests.length > 0,
            "this user has no pending unstake request"
        );
        removeAllRequest(_userAddress);
        delete unstakeRequests[_userAddress];

        uint256 remainingRequest = userInfo[_userAddress].pendingBalance;
        realStakingBalance += remainingRequest;
        userInfo[_userAddress].pendingBalance = 0;
    }

    // ---------------------------------------------------------------------------------------- //
    // ********************************** Internal Functions ********************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice remove all unstake requests for a user
     * @param _userAddress user's address
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
     * @notice Finish the deposit process
     * @dev LPValue will not change during deposit
     * @param _userAddress Address of the user who deposits
     * @param _amount Amount he deposits
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

        userInfo[_userAddress].depositTime = block.timestamp;

        emit Stake(_userAddress, _amount);
    }

    /**
     * @notice _withdraw: finish the withdraw action, only when meeting the conditions
     * @dev LPValue will not change during withdraw
     * @param _userAddress address of the user who withdraws
     * @param _amount the amount he withdraws
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

        emit Unstake(_userAddress, _amount);
    }

    /**
     * @notice Distribute the premium to lottery and emergency pool
     * @param _premium Premium amount to be distributed
     */
    function _distributePremium(uint256 _premium) internal {
        uint256 premiumToLottery = (_premium *
            doDiv(rewardDistribution[1], 100)) / 1e18;
        uint256 premiumToEmergency = (_premium *
            doDiv(rewardDistribution[2], 100)) / 1e18;

        // Transfer some reward to emergency pool and lottery pool
        USDT.safeTransfer(address(emergencyPool), premiumToEmergency);
        USDT.safeTransfer(address(degisLottery), premiumToLottery);

        // Record this injection
        uint256 currentLotteryId = degisLottery.viewCurrentLotteryId();
        degisLottery.injectFunds(currentLotteryId, premiumToLottery);

        emit PremiumDistributed(premiumToEmergency, premiumToLottery);
    }

    /**
     * @notice Update the value of each lp token
     * @dev Normally it will update when claim or expire
     */
    function _updateLPValue() internal {
        uint256 totalLP = IERC20(DLPToken).totalSupply();
        uint256 totalBalance = IERC20(USDT).balanceOf(address(this));

        LPValue = doDiv(totalBalance - activePremiums, totalLP);
    }

    /**
     * @notice When some capacity unlocked, deal with the unstake queue
     * @dev Normally we do not need this process
     * @param remainingPayoff Remaining payoff amount
     */
    function _dealUnstakeQueue(uint256 remainingPayoff) internal {
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

                        for (
                            uint256 k = 0;
                            k < unstakeRequests[pendingUser].length - 1;
                            k += 1
                        ) {
                            unstakeRequests[pendingUser][k] = unstakeRequests[
                                pendingUser
                            ][k + 1];
                        }
                        unstakeRequests[pendingUser].pop();

                        _withdraw(pendingUser, pendingAmount);
                    } else {
                        unstakeRequests[pendingUser][j]
                            .pendingAmount -= remainingPayoff;
                        unstakeRequests[pendingUser][j]
                            .fulfilledAmount += remainingPayoff;
                        _withdraw(pendingUser, remainingPayoff);

                        remainingPayoff = 0;
                        break;
                    }
                }
            } else break;
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
