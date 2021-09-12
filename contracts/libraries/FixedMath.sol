// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library FixedMath {
    using FixedPoint for *;

    /**
     * @notice calculate the fixed point form of collateral factor
     * @param _numerator: the factor input
     * @param _denominator: 100, the divider
     */
    function calcFactor(uint256 _numerator, uint256 _denominator)
        public
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        return FixedPoint.fraction(_numerator, _denominator);
    }
}
