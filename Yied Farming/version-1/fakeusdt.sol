// SPDX-License-Identifier: MIT LICENSE

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


pragma solidity ^0.8.7;

contract USDT is ERC20, ERC20Burnable, Ownable, AccessControl {

  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  mapping(address => uint256) private _balances;

  uint256 private _totalSupply;

  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  constructor() ERC20("USD Tether", "USDT") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());
      }

  function mint(address to, uint256 amount) external {
    require(hasRole(MANAGER_ROLE, _msgSender()), "Not allowed");
    _totalSupply = _totalSupply.add(amount);
    _balances[to] = _balances[to].add(amount);
    _mint(to, amount);
  }

}