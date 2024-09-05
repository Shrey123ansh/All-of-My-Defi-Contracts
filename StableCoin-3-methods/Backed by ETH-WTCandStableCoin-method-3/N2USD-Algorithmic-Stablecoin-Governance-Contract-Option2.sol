// SPDX-License-Identifier: MIT LICENSE


pragma solidity ^0.8.18.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./n2usd.sol";
import "./n2dr.sol";

contract N2DUSDGovern is Ownable, ReentrancyGuard, AccessControl { 
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct SupChange {
        string method;
        uint256 amount;
        uint256 timestamp;
        uint256 blocknum;
    }

    struct ReserveList {
        IERC20 colToken;
    }

    mapping (uint256 => ReserveList) public rsvList;

    N2USD private n2usd;
    N2DR private n2dr;
    address private reserveContract;
    uint256 public n2dusdsupply;
    uint256 public n2drsupply;
    address public datafeed;
    uint256 public supplyChangeCount;
    uint256 public stableColatPrice = 1e18; 
    uint256 public stableColatAmount;
    uint256 private constant COL_PRICE_TO_WEI = 1e10;
    uint256 private constant WEI_VALUE = 1e18;
    uint256 public unstableColatAmount;
    uint256 public unstableColPrice;
    uint256 public reserveCount;

    mapping (uint256 => SupChange) public _supplyChanges;

    bytes32 public constant GOVERN_ROLE = keccak256("GOVERN_ROLE");

    event RepegAction(uint256 time, uint256 amount);
    event Withdraw(uint256 time, uint256 amount);

    constructor(N2USD _n2usd, N2DR _n2dr)Ownable(_msgSender()) {
        n2usd = _n2usd;
        n2dr = _n2dr;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(GOVERN_ROLE, _msgSender());
    }

    function addColateralToken(IERC20 colcontract) external nonReentrant {
        require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
        rsvList[reserveCount].colToken = colcontract;
        reserveCount++;
    }

    function setReserveContract(address reserve) external nonReentrant {
        require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
        reserveContract = reserve;
    }

    function setN2drTokenPrice(uint256 marketcap) external nonReentrant {
        require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
        n2drsupply = n2dr.totalSupply();
        unstableColPrice = ((marketcap).mul(n2drsupply)).div(WEI_VALUE);
    }


    function colateralReBalancing() internal returns (bool) {
        require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
        uint256 stableBalance = rsvList[0].colToken.balanceOf(reserveContract);
        uint256 unstableBalance = rsvList[1].colToken.balanceOf(reserveContract);
        if (stableBalance != stableColatAmount) {
            stableColatAmount = stableBalance;
        }
        if (unstableBalance != stableColatAmount) {
            unstableColatAmount = unstableBalance;
        }
        return true;
    }

    function setN2USDSupply(uint256 totalSupply) external {
         require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
         n2dusdsupply = totalSupply;
    }

    function validatePeg() external nonReentrant {
        require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
        bool result = colateralReBalancing();
        if (result = true) {
            uint256 rawcolvalue = (stableColatAmount.mul(WEI_VALUE)).add(unstableColatAmount.mul(unstableColPrice));
            uint256 colvalue = rawcolvalue.div(WEI_VALUE);
            if (colvalue < n2dusdsupply) {
                uint256 supplyChange = n2dusdsupply.sub(colvalue);
                uint256 burnAmount = (supplyChange.div(unstableColPrice)).mul(WEI_VALUE);
                n2dr.burn(burnAmount);
                _supplyChanges[supplyChangeCount].method = "Burn";
                _supplyChanges[supplyChangeCount].amount = supplyChange;
            }
            if (colvalue > n2dusdsupply) {
                uint256 supplyChange = colvalue.sub(n2dusdsupply);
                n2usd.mint(supplyChange);
                _supplyChanges[supplyChangeCount].method = "Mint";
                _supplyChanges[supplyChangeCount].amount = supplyChange;
            }
        _supplyChanges[supplyChangeCount].blocknum = block.number;
        _supplyChanges[supplyChangeCount].timestamp = block.timestamp;
        supplyChangeCount++;
        emit RepegAction(block.timestamp, colvalue);
        }
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
        n2usd.transfer(address(msg.sender), _amount);
        emit Withdraw(block.timestamp, _amount);
    }

    function withdrawN2dr(uint256 _amount) external nonReentrant {
        require(hasRole(GOVERN_ROLE, _msgSender()), "Not allowed");
        n2dr.transfer(address(msg.sender), _amount);
        emit Withdraw(block.timestamp, _amount);
    }


}

