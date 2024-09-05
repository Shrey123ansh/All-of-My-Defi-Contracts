// SPDX-License-Identifier: MIT LICENSE

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

pragma solidity ^0.8.17.0;

contract WETH is ERC20, ERC20Burnable, Ownable {

  using SafeERC20 for ERC20;

  constructor() ERC20("Wrapped ETH", "WETH") {}

  function mint(uint256 amount) external onlyOwner {
    _mint(msg.sender, amount);
  }

}
