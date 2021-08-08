// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "./libraries/NFTInfo.sol";
import "./interfaces/IPolicyFlow.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PolicyToken is ERC721 {
    address public owner;
    using Strings for uint256;

    enum PolicyStatus {
        INI,
        SOLD,
        DECLINED,
        EXPIRED,
        CLAIMED
    }

    struct PolicyTokenURIParam {
        uint256 productId;
        bytes32 policyId;
        address owner;
        uint256 premium;
        uint256 payoff;
        uint256 purchaseDate;
        uint256 expiryDate;
        uint256 status;
    }

    IPolicyFlow policyFlow;

    uint256 _nextId;

    constructor(IPolicyFlow _policyFlow) ERC721("DegisPolicyToken", "DEGISPT") {
        _nextId = 1;
        policyFlow = _policyFlow;
    }

    function updatePolicyFlow(IPolicyFlow _policyFlow) public {
        policyFlow = _policyFlow;
    }

    function getNextId() public view returns (uint256) {
        return _nextId;
    }

    function mintPolicyToken(address _to) public {
        uint256 tokenId = _nextId++;
        _mint(_to, tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(tokenId < _nextId, "error, tokenId too large!");
        return getTokenURI(tokenId);
        // "This is a test message. product Id: 0, policy Id: 1, premium: 1, payoff: 10";
    }

    function getTokenURI(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        (
            bytes32 _policyId,
            uint256 _productId,
            address _owner,
            uint256 _premium,
            uint256 _payoff,
            uint256 _expiryDate
        ) = policyFlow.getPolicyInfoByCount(tokenId);

        // uint256 _productId = policyFlow.policyList[_policyId].productId;
        // address _owner = policyFlow.policyList[_policyId].userAddress;
        // uint256 _premium = policyFlow.policyList[_policyId].premium;
        // uint256 _payoff = policyFlow.policyList[_policyId].payoff;
        // uint256 _expiryDate = policyFlow.policyList[_policyId].expiryDate;
        return
            constructTokenURI(
                PolicyTokenURIParam(
                    _productId,
                    _policyId,
                    _owner,
                    _premium,
                    _payoff,
                    100000,
                    _expiryDate,
                    1
                )
            );
    }

    function constructTokenURI(PolicyTokenURIParam memory _params)
        public
        pure
        returns (string memory)
    {
        uint256 status = uint256(_params.status);
        return
            string(
                abi.encodePacked(
                    "product id:",
                    _params.productId.toString(),
                    ",",
                    "policy id:",
                    _params.policyId,
                    ",",
                    "premium:",
                    (_params.premium / 10**18).toString(),
                    ",",
                    "payoff:",
                    (_params.payoff / 10**18).toString(),
                    ",",
                    "PolicyStatus:",
                    status.toString(),
                    "."
                )
            );
    }
}
