// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";

contract ToStrings {
    using Strings for uint256;

    /**
     * @notice transfer an address to a string
     * @param _addr: input address
     * @return string form of _addr
     */
    function addressToString(address _addr)
        public
        pure
        returns (string memory)
    {
        return (uint256(uint160(_addr))).toHexString(20);
    }

    /**
     * @notice transfer bytes32 to string (not change the content)
     * @param _bytes: input bytes32
     * @return string form of _bytes
     */
    function bytes32ToString(bytes32 _bytes)
        public
        pure
        returns (string memory)
    {
        return (uint256(_bytes)).toHexString(32);
    }

    /**
     * @notice transfer bytes32 to string (human-readable form)
     * @param _bytes: input bytes32
     * @return string form of _bytes
     */
    function bytes32ToHumanString(bytes32 _bytes)
        public
        pure
        returns (string memory)
    {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes[i];
        }
        return string(bytesArray);
    }

    /**
     * @notice Transfer a bytes(ascii) to uint
     * @param s input bytes
     * @return the number
     */
    function bytesToUint(bytes32 s) public pure returns (uint256) {
        bytes memory b = new bytes(32);
        for (uint256 i; i < 32; i++) {
            b[i] = s[i];
        }
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48);
            }
        }
        return result;
    }

    /**
     * @notice Just a function for encodePacked some strings
     */
    function encodePack1(
        uint256 _order,
        string memory _flightNumber,
        uint256 _policyId,
        uint256 _productId,
        address _userAddress
    ) public pure returns (string memory _result1) {
        _result1 = string(
            abi.encodePacked(
                "\nPolicy",
                _order.toString(),
                ": \n{FlightNumber: ",
                _flightNumber,
                ": \nPolicyId: ",
                _policyId.toString(),
                ", \nProductId: ",
                _productId.toString(),
                ", \nBuyerAddress: ",
                addressToString(_userAddress)
            )
        );
    }

    function encodePack2(
        uint256 _premium,
        uint256 _payoff,
        uint256 _purchaseDate,
        uint256 _departureDate,
        uint256 _landingDate,
        uint256 _status,
        string memory _isUsed,
        uint256 _delayResult
    ) public pure returns (string memory _result2) {
        _result2 = string(
            abi.encodePacked(
                ", \nPremium: ",
                (_premium / 10**18).toString(),
                ", \nPayoff: ",
                (_payoff / 10**18).toString(),
                ", \nPurchaseDate: ",
                (_purchaseDate).toString(),
                ", \nDepartureDate: ",
                (_departureDate).toString(),
                ", \nLandingDate: ",
                (_landingDate).toString(),
                ", \nStatus: ",
                uint256(_status).toString(),
                ", \nIsUsed: ",
                _isUsed,
                ", \nDelay Results: ",
                _delayResult.toString(),
                "}"
            )
        );
    }
}
