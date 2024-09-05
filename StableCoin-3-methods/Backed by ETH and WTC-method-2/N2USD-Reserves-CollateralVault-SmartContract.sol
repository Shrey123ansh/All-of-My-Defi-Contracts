// SPDX-License-Identifier: MIT LICENSE

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


pragma solidity ^0.8.17.0;

contract N2USDReserves is Ownable, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public currentReserveId;

    struct ReserveVault {
        IERC20 collateral;
        uint256 amount;
    }

    mapping(uint256 => ReserveVault) public _rsvVault;

    event Withdraw (uint256 indexed vid, uint256 amount);
    event Deposit (uint256 indexed vid, uint256 amount);

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
    }

    function checkReserveContract(IERC20 _collateral) internal view {
        for(uint256 i; i < currentReserveId; i++){
            require(_rsvVault[i].collateral != _collateral, "Collateral Address Already Added");
        }
    }

    function addReserveVault(IERC20 _collateral) external {
        require(hasRole(MANAGER_ROLE, _msgSender()), "Not allowed");
        checkReserveContract(_collateral);
        _rsvVault[currentReserveId].collateral = _collateral;
        currentReserveId++;
    }

    function depositCollateral(uint256 vid, uint256 amount) external {
        require(hasRole(MANAGER_ROLE, _msgSender()), "Not allowed");
        IERC20 reserves = _rsvVault[vid].collateral;
        reserves.safeTransferFrom(address(msg.sender), address(this), amount);
        uint256 currentVaultBalance = _rsvVault[vid].amount;
        _rsvVault[vid].amount = currentVaultBalance.add(amount);
        emit Deposit(vid, amount);
    }

    function withdrawCollateral(uint256 vid, uint256 amount) external {
        require(hasRole(MANAGER_ROLE, _msgSender()), "Not allowed");
        IERC20 reserves = _rsvVault[vid].collateral;
        uint256 currentVaultBalance = _rsvVault[vid].amount;
        if (currentVaultBalance >= amount) {
            reserves.safeTransfer(address(msg.sender), amount);
            _rsvVault[vid].amount = currentVaultBalance.sub(amount);
            emit Withdraw(vid, amount);
        }
    }
}
