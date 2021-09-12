// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol"; // test version. use random number for test

contract GetRandomness is VRFConsumerBase {
    // The owner of this address
    address public owner;

    // LINK Token address on rinkeby: 0x01BE23585060835E02B77ef475b0Cc51aA1e0709
    address public LINKToken;

    // VRF Consumer on rinkeby: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
    address public VRFCoordinator;

    // Used for chainlink request
    uint256 internal fee;
    bytes32 internal keyHash;

    // The random number result
    uint256 public randomResult;

    event ReceiveRandomness(bytes32, uint256);
    event SendRequest(bytes32);

    constructor(
        address _VRFConsumer,
        address _LINKToken,
        bytes32 _keyHash
    ) VRFConsumerBase(_VRFConsumer, _LINKToken) {
        owner = msg.sender;
        LINKToken = _LINKToken;
        VRFCoordinator = _VRFConsumer;
        fee = 0.1 * 10**18; // 0.1 LINK per request
        keyHash = _keyHash;
    }

    function getRandomNumber() public returns (bytes32) {
        require(LINK.balanceOf(address(this)) >= fee, "not enough LINK");
        bytes32 requestId = requestRandomness(keyHash, fee);
        emit SendRequest(requestId);
        return requestId;
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        randomResult = _randomness;
        emit ReceiveRandomness(_requestId, _randomness);
    }
}
