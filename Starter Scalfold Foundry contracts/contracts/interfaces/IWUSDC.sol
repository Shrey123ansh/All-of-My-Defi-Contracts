pragma solidity ^0.8.20;

interface IWUSDC {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}
