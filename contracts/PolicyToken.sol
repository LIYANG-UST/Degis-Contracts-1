// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IPolicyFlow.sol";
import "./interfaces/IPolicyToken.sol";

contract PolicyToken is ERC721Enumerable, Ownable, IPolicyToken {
    using Strings for uint256;

    IPolicyFlow policyFlow;

    uint256 public _nextId;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(address _policyFlow) ERC721("DegisPolicyToken", "DEGISPT") {
        _nextId = 1;
        policyFlow = IPolicyFlow(_policyFlow);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Function ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the next token Id of PolicyToken
     *         The current max token Id is (_nextId - 1)
     * @return Next token Id
     */
    function getNextId() public view returns (uint256) {
        return _nextId;
    }

    /**
     * @notice Get the tokenURI of a policy
     * @param _tokenId: Token Id of the policy token
     * @return The tokenURI in string form
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721, IPolicyToken)
        returns (string memory)
    {
        require(_tokenId < _nextId, "error, tokenId too large!");
        return getTokenURI(_tokenId);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Owner Function ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
       @notice Update the policyFlow address if it has been updated
       @param _policyFlow: New policyFlow contract address
     */
    function updatePolicyFlow(address _policyFlow) external onlyOwner {
        policyFlow = IPolicyFlow(_policyFlow);
    }

    /**
     * @notice Mint a new policy token to an address
     * @param _to: The receiver address
     */
    function mintPolicyToken(address _to) public onlyOwner {
        uint256 tokenId = _nextId++;
        _mint(_to, tokenId);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Main Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Transfer the owner of a policy token and update the information in policyFlow
     * @param _from: The original owner of the policy
     * @param _to: The new owner of the policy
     * @param _tokenId: Token id of the policy
     */
    function transferOwner(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        transferFrom(_from, _to, _tokenId);
        policyFlow.policyOwnerTransfer(_tokenId, _from, _to);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the tokenURI, the metadata is from policyFlow contract
     * @param _tokenId: Token Id of the policy token
     */
    function getTokenURI(uint256 _tokenId) public view returns (string memory) {
        PolicyInfo memory info = policyFlow.getPolicyInfoById(_tokenId);

        return
            constructTokenURI(
                PolicyTokenURIParam(
                    info.productId,
                    info.flightNumber,
                    info.policyId,
                    info.buyerAddress,
                    info.premium,
                    info.payoff,
                    info.purchaseDate,
                    info.departureDate,
                    info.landingDate,
                    uint256(info.status)
                )
            );
    }

    /**
     * @notice Construct the metadata of a specific policy token
     */

    function constructTokenURI(PolicyTokenURIParam memory _params)
        internal
        pure
        returns (string memory)
    {
        uint256 status = uint256(_params.status);
        return
            string(
                abi.encodePacked(
                    "ProductId: ",
                    _params.productId.toString(),
                    ", ",
                    "FlightNumber: ",
                    _params.flightNumber,
                    "PolicyId: ",
                    _params.policyId.toString(),
                    ", ",
                    "BuyerAddress: ",
                    addressToString(_params.owner),
                    "Premium: ",
                    (_params.premium / 10**18).toString(),
                    ", ",
                    "Payoff: ",
                    (_params.payoff / 10**18).toString(),
                    ", ",
                    "PurchaseDate: ",
                    _params.purchaseDate.toString(),
                    ", ",
                    "DepartureDate:",
                    _params.departureDate.toString(),
                    ", ",
                    "LandingDate: ",
                    _params.landingDate.toString(),
                    ", ",
                    "PolicyStatus: ",
                    status.toString(),
                    "."
                )
            );
    }

    /**
     * @notice Bytes to string (not human-readable form)
     * @param _bytes: Input bytes
     * @return String form
     */
    function byToString(bytes32 _bytes) internal pure returns (string memory) {
        return (uint256(_bytes)).toHexString(32);
    }

    /**
     * @notice Transfer address to string (not change the content)
     * @param _addr: Input address
     * @return String form
     */
    function addressToString(address _addr)
        internal
        pure
        returns (string memory)
    {
        return (uint256(uint160(_addr))).toHexString(20);
    }
}
