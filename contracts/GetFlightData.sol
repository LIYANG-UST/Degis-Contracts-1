// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/Policy.sol";

contract GetFlightData {
    address public owner;

    address chainlinkOracle;

    struct delayStatus {
        bool isDelay;
        bool isCancelled;
        uint256 delayTime;
    }

    constructor(address _oracle) {
        owner = msg.sender;
        chainlinkOracle = _oracle;
    }

    // @function getFinalStatus: get the final status about the delay
    function getFinalStatus() public returns (delayStatus memory _status) {}

    function getProbability() public returns (fixed _probability) {}
}
