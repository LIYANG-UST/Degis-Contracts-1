// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/Policy.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol"; // test version. use random number for test

contract GetFlightData is VRFConsumerBase {
    address public owner;

    // LINK Token address on rinkeby: 0x01BE23585060835E02B77ef475b0Cc51aA1e0709
    address public LINKToken;

    // VRF Consumer on rinkeby: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
    address public VRFCoordinator;

    address public chainlinkOracle;

    uint256 internal fee;
    bytes32 internal keyHash;

    struct delayStatus {
        bool isDelay;
        bool isCancelled;
        uint256 delayTime;
    }

    event ReceiveRandomness(bytes32, uint256);

    mapping(bytes32 => delayStatus) delayStatusList;

    constructor(
        address _oracle,
        address _VRFConsumer,
        address _LINKToken,
        bytes32 _keyHash
    ) VRFConsumerBase(_VRFConsumer, _LINKToken) {
        owner = msg.sender;
        chainlinkOracle = _oracle;
        LINKToken = _LINKToken;
        VRFCoordinator = _VRFConsumer;
        fee = 0.1 * 10**18;
        keyHash = _keyHash; // 0.1 LINK
    }

    function getRandomNumber() public returns (bytes32) {
        require(LINK.balanceOf(address(this)) >= fee, "not enough LINK");
        bytes32 requestId = requestRandomness(keyHash, fee);
        return requestId;
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
        returns (uint256)
    {
        uint256 randomResult = _randomness;
        if (randomResult % 2 == 0) {
            delayStatusList["test"] = delayStatus(false, false, 0);
        } else {
            delayStatusList["test"] = delayStatus(true, false, 100);
        }
        emit ReceiveRandomness(_requestId, _randomness);
        return _randomness;
    }

    // @function getFinalStatus: get the final status about the delay
    function getFinalStatus() public returns (delayStatus memory _status) {
        return delayStatus(true, true, 404);
    }
}
