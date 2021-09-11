// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EmergencyPool is Ownable {
    using SafeERC20 for IERC20;

    // This is the address of USDC (maybe usd-anything).
    IERC20 public USDC_TOKEN;

    // Token balance for emergency
    uint256 public emergencyBalance;

    // PoolInfo: the information about this pool
    struct PoolInfo {
        string poolName;
        uint256 poolId;
    }

    PoolInfo poolInfo;

    constructor(address _usdcAddress) {
        transferOwnership(msg.sender);
        USDC_TOKEN = IERC20(_usdcAddress);
        emergencyBalance = 0; // You do not need to initialize an uint as 0
        poolInfo = PoolInfo("Degis Emergency Pool", 666);
    }

    event Deposit(address indexed userAddress, uint256 amount);
    event Withdraw(address indexed userAddress, uint256 amount);

    /**
     * @notice view function, show the pool's name
     */
    function getPoolName() public view returns (string memory) {
        return poolInfo.poolName;
    }
    /**
     * @notice view function, show the pool's id
     */
    function getPoolId() public view returns (uint256) {
        return poolInfo.poolId;
    }

    
    /**
     * @notice stake into the pool
     * @param _userAddress: user's address
     * @param _amount: the amount that the user want to stake
     */
    function deposit(address _userAddress, uint256 _amount) external {
        require(_amount >= 0, "Please deposit some funds");
        emergencyBalance += _amount;
        _deposit(_userAddress, _amount);
        emit Deposit(_userAddress, _amount);
    }

    /**
     * @notice emergencyWithdraw: unstake the asset (only by the owner)
     * @param _userAddress: user's address
     * @param _amount: the amount that the user want to unstake
     */
    // the ownership need to be transferred to another contract in the future
    function emergencyWithdraw(address _userAddress, uint256 _amount)
        external
        onlyOwner
    {
        require(
            _amount <= emergencyBalance,
            "not enough balance to be unlocked"
        );
        emergencyBalance -= _amount;
        _withdraw(_userAddress, _amount);
        emit Withdraw(_userAddress, _amount);
    }

    /**
     * @notice finish the deposit process
     * @param _userAddress: address of the user who deposits
     * @param _amount: the amount he deposits
     */
    function _deposit(address _userAddress, uint256 _amount) internal {
        USDC_TOKEN.safeTransferFrom(_userAddress, address(this), _amount);
    }

    /**
     * @notice _withdraw: finish the withdraw action, only when meeting the conditions
     * @param _userAddress: address of the user who withdraws
     * @param _amount: the amount he withdraws
     */
    function _withdraw(address _userAddress, uint256 _amount) internal {
        // 加入给用户转账的代码
        // 使用其他ERC20 代币 usdc/dai
        USDC_TOKEN.safeTransfer(_userAddress, _amount);
    }

}
