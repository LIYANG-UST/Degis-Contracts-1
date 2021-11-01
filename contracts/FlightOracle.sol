// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./interfaces/IPolicyFlow.sol";

contract FlightOracle is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    IPolicyFlow policyFlow;

    uint256 fee;
    string private FLIGHT_STATUS_URL = "http://39.101.132.228:8000/live/";
    address private oracleAddress;
    bytes32 private jobId;

    constructor(address _policyFlow) {
        policyFlow = IPolicyFlow(_policyFlow);
    }

    /**
     * @notice Creates a request to the specified Oracle contract address
     * @dev This function ignores the stored Oracle contract address and
     *      will instead send the request to the address specified
     * @param _oracle The Oracle contract address to send the request to
     * @param _jobId The bytes32 JobID to be executed
     * @param _url The URL to fetch data from
     * @param _path The dot-delimited path to parse of the response
     * @param _times The number to multiply the result by
     */
    function newOracleRequest(
        address _oracle,
        bytes32 _jobId,
        uint256 _payment,
        string memory _url,
        string memory _path,
        int256 _times
    ) public returns (bytes32) {
        Chainlink.Request memory req = buildChainlinkRequest(
            _jobId,
            address(this),
            this.fulfill.selector
        );
        req.add("url", _url);
        req.add("path", _path);
        req.addInt("times", _times);
        return sendChainlinkRequestTo(_oracle, req, _payment);
    }

    /**
     * @notice The fulfill method from requests created by this contract
     * @dev The recordChainlinkFulfillment protects this function from being called
     *      by anyone other than the oracle address that the request was sent to
     * @param _requestId The ID that was generated for the request
     * @param _data The answer provided by the oracle
     */
    function fulfill(bytes32 _requestId, uint256 _data)
        public
        recordChainlinkFulfillment(_requestId)
    {
        policyFlow.finalSettlement(_requestId, _data);
    }
}
