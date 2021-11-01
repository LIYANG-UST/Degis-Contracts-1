// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IFlightOracle {
    function newOracleRequest(
        address,
        bytes32,
        uint256,
        string memory,
        string memory,
        uint256
    ) external returns (bytes32);
}
