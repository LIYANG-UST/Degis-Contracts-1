// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/IPolicyFlow.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/ToStrings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PolicyToken is ERC721, Ownable {
    using Strings for uint256;

    struct PolicyTokenURIParam {
        uint256 productId;
        string flightNumber;
        bytes32 policyId;
        uint256 totalOrder;
        address owner;
        uint256 premium;
        uint256 payoff;
        uint256 purchaseDate;
        uint256 departureDate;
        uint256 landingDate;
        uint256 status;
    }

    IPolicyFlow policyFlow;

    uint256 public _nextId;

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

    function mintPolicyToken(address _to) public onlyOwner {
        uint256 tokenId = _nextId++;
        _mint(_to, tokenId);
    }

    function transferOwner(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        transferFrom(_from, _to, _tokenId);
        policyFlow.policyOwnerTransfer(_tokenId, _from, _to);
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
            string memory _flightNumber,
            bytes32 _policyId,
            uint256 _productId,
            address _owner,
            uint256 _premium,
            uint256 _payoff,
            uint256 _purchaseDate,
            uint256 _departureDate,
            uint256 _landingDate,
            uint256 _status
        ) = policyFlow.getPolicyInfoByCount(tokenId);

        return
            constructTokenURI(
                PolicyTokenURIParam(
                    _productId,
                    _flightNumber,
                    _policyId,
                    tokenId,
                    _owner,
                    _premium,
                    _payoff,
                    _purchaseDate,
                    _departureDate,
                    _landingDate,
                    _status
                )
            );
    }

    function constructTokenURI(PolicyTokenURIParam memory _params)
        internal
        pure
        returns (string memory)
    {
        uint256 status = uint256(_params.status);
        return
            string(
                abi.encodePacked(
                    "Product id: ",
                    _params.productId.toString(),
                    ",",
                    "Flight Number: ",
                    _params.flightNumber,
                    "Policy id: ",
                    byToString(_params.policyId),
                    ",",
                    "Total Order: ",
                    _params.totalOrder.toString(),
                    ",",
                    "BuyerAddress: ",
                    addressToString(_params.owner),
                    "Premium:",
                    (_params.premium / 10**18).toString(),
                    ",",
                    "Payoff:",
                    (_params.payoff / 10**18).toString(),
                    ",",
                    "PurchaseDate:",
                    _params.purchaseDate.toString(),
                    ",",
                    "DepartureDate:",
                    _params.departureDate.toString(),
                    ",",
                    "LandingDate:",
                    _params.landingDate.toString(),
                    ",",
                    "PolicyStatus:",
                    status.toString(),
                    "."
                )
            );
    }

    function byToString(bytes32 _bytes) internal pure returns (string memory) {
        return (uint256(_bytes)).toHexString(32);
    }

    function addressToString(address _addr)
        internal
        pure
        returns (string memory)
    {
        return (uint256(uint160(_addr))).toHexString(20);
    }
}
