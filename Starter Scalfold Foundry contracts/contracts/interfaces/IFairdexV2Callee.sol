pragma solidity ^0.8.20;

interface IFairdexV2Callee {
    function FairdexV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}
