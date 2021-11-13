// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPolicyToken is IERC721 {
    function mintPolicyToken(address) external;

    function tokenURI(uint256) external returns (string memory);

    function getTokenURI(uint256) external returns (string memory);
}
