// SPDX-License-Identifier: MIT LICENSE

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./N2D-ERC20-N2DRewards-Token-Final.sol";

pragma solidity ^0.8.7;

contract N2DRPay is Ownable, AccessControl {

  N2DRewards public n2dr;

  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

 constructor(N2DRewards _n2dr)Ownable(_msgSender()) {
        n2dr = _n2dr;
         _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
      }

  function safeN2drTransfer(address _to, uint256 _amount) external {
    require(hasRole(MANAGER_ROLE, _msgSender()), "Not allowed");
    uint256 n2drBal = n2dr.balanceOf(address(this));
    if (_amount > n2drBal){
      n2dr.transfer(_to, n2drBal);
    }
    else {
      n2dr.transfer(_to, _amount);
    }
  }
}