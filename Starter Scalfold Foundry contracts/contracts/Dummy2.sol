// SPDX-License-Identifier: MIT

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/utils/math/SafeMath.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/AccessControl.sol";

pragma solidity ^0.8.20;

contract Dummy2 is ERC20, ERC20Burnable, Ownable, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    mapping(address => uint256) private _balances;

    uint256 private _totalSupply;

    constructor() ERC20("Dummy2 Token", "DTT") {}

    function mint(address to, uint256 amount) external {
        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);
        _mint(to, amount);
    }
}
