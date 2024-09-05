pragma solidity ^0.8.20;

interface IFairdexV2Factory {
    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function nDev() external view returns (uint256);

    function dDev() external view returns (uint256);

    function devFee() external view returns (uint32);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;

    function setPercentForAllPairs(uint256 _ndev, uint256 _ddev) external;

    function setDevFeeForAllPairs(uint32 _devFee) external;
}
