// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/token/ERC20/ERC20.sol";

contract PracticeSupplyERC20 is ERC20 {
    constructor() ERC20("Practice ERC20", "PERC") {
        _mint(msg.sender, 1000000000000000000000000);
    }

    fallback() external payable {}

    receive() external payable {}
}
