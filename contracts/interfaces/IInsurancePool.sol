// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IInsurancePool {
    // events

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
    event PurchaseIncentiveChanged(
        uint256 _blocktimestamp,
        uint256 _purchaseIncentiveAmount
    );

    event SendPurchaseIncentive(address _userAddress, uint256 _amount);
    event SetFrozenTime(uint256 _newFrozenTime);
    event PremiumDistributed(
        uint256 _premiumToEmergency,
        uint256 _premiumToLottery
    );

    // view functions

    function getUserBalance(address) external view returns (uint256);

    function getPoolUnlocked() external view returns (uint256);

    function getUnlockedFor(address _userAddress)
        external
        view
        returns (uint256);

    function getLockedFor(address _userAddress) external view returns (uint256);

    function checkCapacity(uint256 _payoff) external view returns (bool);

    // set functions

    function setPurchaseIncentive(uint256 _newIncentive) external;

    function setFrozenTime(uint256 _newFrozenTime) external;

    function setPolicyFlow(address _policyFlowAddress) external;

    function setIncomeDistribution(uint256[3] memory _newDistribution) external;

    function setCollateralFactor(uint256 _factor) external;

    function transferOwnership(address _newOwner) external;

    // main functions

    function stake(address _userAddress, uint256 _amount) external;

    function unstake(uint256 _amount) external;

    function unstakeMax() external;

    function updateWhenBuy(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) external;

    function updateWhenExpire(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress
    ) external;

    function payClaim(
        uint256 _premium,
        uint256 _payoff,
        uint256 _realPayoff,
        address _userAddress
    ) external;

    function revertUnstakeRequest(address _userAddress) external;

    function revertAllUnstakeRequest(address _userAddress) external;
}
