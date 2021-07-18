// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DegisToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EmergencyPool is Ownable {

    IERC20 public USDC_TOKEN; 

    // current total balance of the pool
    uint256 emergencyBalance; 

    // poolInfo: the information about this pool
    struct poolInfo {  
        string poolName;
        uint256 poolId;
    }

    constructor(address _usdcAddress) {
        transferOwnership(msg.sender);
        USDC_TOKEN = IERC20(_usdcAddress);
        emergencyBalance = 0;
    }

    event Deposit(address indexed userAddress, uint256 amount);
    event Withdraw(address indexed userAddress, uint256 amount);

    /**
     * @notice finish the deposit process
     * @param _userAddress: address of the user who deposits
     * @param _amount: the amount he deposits
     */
    function _deposit(address _userAddress, uint256 _amount) internal {
        USDC_TOKEN.transferFrom(address(this), _userAddress, _amount);
    }

    /**
     * @notice _withdraw: finish the withdraw action, only when meeting the conditions
     * @param _userAddress: address of the user who withdraws
     * @param _amount: the amount he withdraws
     */
    function _withdraw(address _userAddress, uint256 _amount) internal {
        // 加入给用户转账的代码
        // 使用其他ERC20 代币 usdc/dai
        USDC_TOKEN.transferFrom(address(this), _userAddress, _amount);
    }

    // @function emergencyDeposit: a user(LP) want to stake some amount of asset
    // @param _userAddress: user's address
    // @param _amount: the amount that the user want to stake
    function emergencyDeposit(address _userAddress, uint256 _amount) public onlyOwner {
        emergencyBalance += _amount;
        _deposit(_userAddress, _amount);
        emit Deposit(_userAddress, _amount);
    }

    /**
     * @notice emergencyWithdraw: a user want to unstake some amount
     * @param _userAddress: user's address
     * @param _amount: the amount that the user want to unstake
     */
    function emergencyWithdraw(address _userAddress, uint256 _amount) public onlyOwner {
        require(
            _amount <= emergencyBalance,
            "not enough balance to be unlocked"
        );
        emergencyBalance -= _amount;
        _withdraw(_userAddress, _amount); 
        emit Withdraw(_userAddress, _amount);
    }
}
