// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FairXToken.sol";
import "openzeppelin/utils/math/SafeMath.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

// The FairX Garden is a fork of MasterChef by SushiSwap
// The biggest change made is using per second instead of per block for rewards
// This is due to Fantoms extremely inconsistent block times
// The other biggest change was the removal of the migration functions
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once FairX is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of FairXs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accFairXPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accFairXPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. FairXs to distribute per block.
        uint256 lastRewardTime; // Last block time that FairXs distribution occurs.
        uint256 accFairXPerShare; // Accumulated FairXs per share, times 1e12. See below.
    }

    // such a FAIRX token!
    FairXToken public fairX;

    // Dev address.
    address public devaddr;
    // fairX tokens created per block.
    uint256 public fairXPerSecond;

    // set a max fairX per second, which can never be higher than 1 per second
    uint256 public constant maxFairXPerSecond = 1e18;

    uint256 public constant MaxAllocPoint = 4000;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block time when fairX mining starts.
    uint256 public immutable startTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        FairXToken _fairX,
        address _devaddr,
        uint256 _fairXPerSecond,
        uint256 _startTime
    ) {
        fairX = _fairX;
        devaddr = _devaddr;
        fairXPerSecond = _fairXPerSecond;
        startTime = _startTime;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Changes fairX token reward per second, with a cap of maxfairX per second
    // Good practice to update pools without messing up the contract
    function setFairXPerSecond(uint256 _fairXPerSecond) external onlyOwner {
        //require(_fairXPerSecond <= maxFairXPerSecond, "setFairXPerSecond: too many fairXs!");

        // This MUST be done or pool rewards will be calculated with new fairX per second
        // This could unfairly punish small pools that dont have frequent deposits/withdraws/harvests
        massUpdatePools();

        fairXPerSecond = _fairXPerSecond;
    }

    function checkForDuplicate(IERC20 _lpToken) internal view {
        uint256 length = poolInfo.length;
        for (uint256 _pid = 0; _pid < length; _pid++) {
            require(
                poolInfo[_pid].lpToken != _lpToken,
                "add: pool already exists!!!!"
            );
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken) external onlyOwner {
        require(_allocPoint <= MaxAllocPoint, "add: too many alloc points!!");

        checkForDuplicate(_lpToken); // ensure you cant add duplicate pools

        massUpdatePools();

        uint256 lastRewardTime = block.timestamp > startTime
            ? block.timestamp
            : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTime: lastRewardTime,
                accFairXPerShare: 0
            })
        );
    }

    // Update the given pool's FairX allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        require(_allocPoint <= MaxAllocPoint, "add: too many alloc points!!");

        massUpdatePools();

        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        _from = _from > startTime ? _from : startTime;
        if (_to < startTime) {
            return 0;
        }
        return _to - _from;
    }

    // View function to see pending FairXs on frontend.
    function pendingFairX(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFairXPerShare = pool.accFairXPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardTime,
                block.timestamp
            );
            uint256 fairXReward = multiplier
                .mul(fairXPerSecond)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accFairXPerShare = accFairXPerShare.add(
                fairXReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accFairXPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(
            pool.lastRewardTime,
            block.timestamp
        );
        uint256 fairXReward = multiplier
            .mul(fairXPerSecond)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);

        fairX.mint(devaddr, fairXReward.div(10));
        fairX.mint(address(this), fairXReward);

        pool.accFairXPerShare = pool.accFairXPerShare.add(
            fairXReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for FairX allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accFairXPerShare).div(1e12).sub(
            user.rewardDebt
        );

        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accFairXPerShare).div(1e12);

        if (pending > 0) {
            safeFairXTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accFairXPerShare).div(1e12).sub(
            user.rewardDebt
        );

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accFairXPerShare).div(1e12);

        if (pending > 0) {
            safeFairXTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransfer(address(msg.sender), _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint oldUserAmount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(address(msg.sender), oldUserAmount);
        emit EmergencyWithdraw(msg.sender, _pid, oldUserAmount);
    }

    // Safe fairX transfer function, just in case if rounding error causes pool to not have enough FairXs.
    function safeFairXTransfer(address _to, uint256 _amount) internal {
        uint256 fairXBal = fairX.balanceOf(address(this));
        if (_amount > fairXBal) {
            fairX.transfer(_to, fairXBal);
        } else {
            fairX.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
