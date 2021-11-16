// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

contract InsurancePoolStore {
    address public policyFlow;

    uint256 public purchaseIncentiveAmount;

    uint256 frozenTime = 7 days; // 7 days

    struct UserInfo {
        uint256 depositTime;
        uint256 premiumDebt; // premium reward debt
        uint256 assetBalance; // the amount of a user's staking in the pool
        uint256 pendingBalance; // the amount in the unstake queue
    }
    mapping(address => UserInfo) userInfo;

    // Basic information about the pool
    struct PoolInfo {
        uint256 totalLP; // total lp amount
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
    mapping(address => UnstakeRequest[]) internal unstakeRequests;

    // list of all unstake users
    address[] internal unstakeQueue;

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
    event PurchaseIncentiveChanged(
        uint256 _blocknumber,
        uint256 _purchaseIncentiveAmount
    );

    event SendPurchaseIncentive(address _userAddress, uint256 _amount);
}
