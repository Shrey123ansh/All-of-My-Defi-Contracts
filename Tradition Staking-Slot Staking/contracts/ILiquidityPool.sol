// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface ILiquidityPool {
    function accessFunds(uint256 _amount, string memory _action) external;
}
