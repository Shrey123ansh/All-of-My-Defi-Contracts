// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./IFairdexV2Pair.sol";

interface ISwapper {
    function swap(
        address fromToken,
        IFairdexV2Pair pair,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function overrideSlippage(address _token) external;

    function setSlippage(uint _amt) external;
}
