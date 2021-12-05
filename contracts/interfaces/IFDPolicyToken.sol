// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IPolicyTypes.sol";

interface IFDPolicyToken is IERC721, IPolicyTypes {
    function mintPolicyToken(address) external;

    function tokenURI(uint256) external view returns (string memory);

    function getTokenURI(uint256) external view returns (string memory);
}
