// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/token/ERC20/ERC20.sol";

contract WUSDC is ERC20 {
    constructor() ERC20("Wrapped USDC", "WUSDC") {}

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external {
        address account = msg.sender;
        _burn(account, _amount);
        (bool success, ) = payable(account).call{value: _amount}("");
        require(success, "failed to send USDC");
    }
}
