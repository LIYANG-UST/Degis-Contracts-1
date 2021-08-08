// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";

library NFTInfo {
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
