// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IEmergencyPool.sol";

/**
 * @title  Emergency Pool
 * @notice Emergency pool in degis will keep a reserve vault for emergency usage.
 *         The asset comes from part of the product's income (currently 10%).
 *         Users can also stake funds into this contract manually.
 *         The owner has the right to withdraw funds from emergency pool and it would be passed to community governance.
 */
contract EmergencyPool is IEmergencyPool {
    address public owner;

    using SafeERC20 for IERC20;

    string public name = "Degis Emergency Pool";

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    /**
     * @notice Transfer the ownership to a new owner
     * @param _newOwner New owner address
     */
    function transferOwnerShip(address _newOwner) external onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(_newOwner);
    }

    /**
     * @notice Manually stake into the pool
     * @param _userAddress User's address
     * @param _amount The amount that the user want to stake
     */
    function deposit(
        address _usdAddress,
        address _userAddress,
        uint256 _amount
    ) external {
        require(_amount > 0, "Please deposit some funds");

        IERC20(_usdAddress).safeTransferFrom(
            _userAddress,
            address(this),
            _amount
        );

        emit Deposit(_usdAddress, _userAddress, _amount);
    }

    /**
     * @notice Withdraw the asset when emergency (only by the owner)
     * @dev The ownership need to be transferred to another contract in the future
     * @param _userAddress User's address
     * @param _amount The amount that the user want to unstake
     */
    function emergencyWithdraw(
        address _usdAddress,
        address _userAddress,
        uint256 _amount
    ) external onlyOwner {
        uint256 balance = IERC20(_usdAddress).balanceOf(address(this));
        require(_amount <= balance, "not enough balance to be unlocked");

        IERC20(_usdAddress).safeTransfer(_userAddress, _amount);
        emit Withdraw(_usdAddress, _userAddress, _amount);
    }
}
