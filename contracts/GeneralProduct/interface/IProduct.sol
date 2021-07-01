// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProduct {
    event NewProduct(uint256 productId);

    function newProduct() external returns (uint256);
}
