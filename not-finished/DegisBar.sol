// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DegisBar is ERC20("DegisBar", "xDEGIS") {
    address public owner;
    using SafeMath for uint256;
    IERC20 public DegisToken;

    constructor(IERC20 _degisAddress) {
        owner = msg.sender;
        DegisToken = _degisAddress;
    }

    /**
     * @notice users deposit Degis Token to enter the pool
     * @param _amount: the amount of Degis Token deposited
     */
    function enter(uint256 _amount) public {
        uint256 totalDegis = DegisToken.balanceOf(address(this));

        uint256 totalShares = totalSupply();

        if (totalShares == 0 || totalDegis == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalDegis);
            _mint(msg.sender, what);
        }

        DegisToken.transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice users deposit Degis Token to enter the pool
     * @param _share: the user's share
     */
    function leave(uint256 _share) public {
        // Gets the amount of xSushi in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Sushi the xSushi is worth
        uint256 what = _share.mul(DegisToken.balanceOf(address(this))).div(
            totalShares
        );
        _burn(msg.sender, _share);
        DegisToken.transfer(msg.sender, what);
    }
}
