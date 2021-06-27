// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/utils/math/safeMath.sol";
import "./GetFlightData.sol";

contract InsuranceMath {
    address public owner;

    GetFlightData dataLoader;

    constructor(GetFlightData _dataLoader) {
        owner = msg.sender;
        dataLoader = _dataLoader;
    }

    function calcPremium() public returns (uint256) {
        fixed probability = 1;
        uint256 premium = uint256(probability);
        return premium;
    }
}
