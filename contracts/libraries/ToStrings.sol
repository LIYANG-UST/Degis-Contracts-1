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
}
