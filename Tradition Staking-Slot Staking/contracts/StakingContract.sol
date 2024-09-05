// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "openzeppelin/utils/math/SafeMath.sol";
import "./ILiquidityPool.sol";

/**
 * @title Stake USDC tokens and earn rewards
 * @author https://anmol-dhiman.netlify.app/
 * @notice Dynamic Staking, APY and Compounding frequency
 */
contract StakingContract is OwnableUpgradeable, ReentrancyGuard {
    using SafeMath for uint256; // Using SafeMath for safe arithmetic operations

    // Flag to pause staking
    bool public pause;

    // Annual Percentage Yield in divid of 100
    // uint16 public apy;

    // minimum USDC token to be staked by user
    uint256 public minimumStake;

    uint256 public frequency;

    // this is the old struct block
    struct Stake {
        uint256 amount; // Amount of tokens staked
        uint32 startTime; // Timestamp when staking occurred
        uint256 rewards; // Accumulated rewards for the stake
    }

    struct APY {
        uint16 value;
        uint32 changeTime;
    }

    struct Slot {
        uint256 amount;
        uint256 rewards;
        uint32 startTime;
        uint256 id;
    }

    struct SlotStake {
        uint256 counter;
        // using 0 base indexing to store the staking slots
        mapping(uint256 => Slot) slotStake;
    }

    // Maps users to their stakes
    // mapping(address => Stake) public stakes;
    mapping(address => SlotStake) public stakes;

    APY[] public apy;

    ILiquidityPool public liquidityPool;

    event Staked(
        address indexed user,
        uint256 amount,
        uint32 stakeTime,
        uint256 slotId
    );
    event ReStaked(
        address indexed user,
        uint256 amount,
        uint32 stakeTime,
        uint256 slotId,
        uint256 rewardsLeft
    );

    event Unstaked(
        address indexed user,
        uint256 amount,
        uint32 unstakeTime,
        uint256 slotid,
        uint256 rewards
    );
    event UnstakedTokens(
        address indexed user,
        uint256 amount,
        uint32 unstakeTime,
        uint256 _slotId,
        uint256 rewardsLeft
    );
    event UnstakedAllTokens(
        address indexed user,
        uint256 totalAmount,
        uint256 rewards,
        uint32 unstakeTime
    );
    event RewardClaimed(
        address indexed user,
        uint256 totalReward,
        uint32 timeOfClaim,
        uint256 slotId,
        uint256 rewardsLeft
    );

    event AllRewardClaimed(
        address indexed user,
        uint256 totalReward,
        uint32 timeOfClaim
    );
    event AmountMigrated(
        uint256 amount,
        address newAddress,
        uint32 migrationTime
    );
    event RestakedAll(address user, uint256 restakedAmount, uint32 timeStamp);

    event MinimumStakeUpdated(uint256 minimumStake, uint32 timeStamp);
    event FrequencyUpdated(uint256 frequency, uint32 timeStamp);
    event ApyUpdated(uint256 apy, uint32 timeStamp);
    event LiquidityPoolUpdated(address newPool, uint32 timeStamp);

    /**
     * @dev Proxy initializer function sets new owner other than admin
     * @param _apy  = 18
     * @param _owner The owner of this contract
     * @param _minimumStake = 100000000000000000000
     * @param _frequency = 31536000
     */
    function initialize(
        uint16 _apy,
        uint256 _minimumStake,
        uint256 _frequency,
        address _liquidityPool,
        address _owner
    ) external initializer {
        apy.push(APY(_apy, uint32(block.timestamp)));
        minimumStake = _minimumStake;
        frequency = _frequency;
        liquidityPool = ILiquidityPool(_liquidityPool);
        __Ownable_init();
        transferOwnership(_owner);
    }

    fallback() external payable {}

    receive() external payable {}

    /**
     * @dev Stake tokens into the contract.
     * @notice Native USDC token more or equal to minimum value should be provided by the user
     */
    function stake() external payable {
        require(
            msg.value >= minimumStake,
            "Amount must be greater than minimum value USDC Tokens"
        );
        require(!pause, "Please wait until the staking is unpaused");

        address user = msg.sender;

        stakes[user].slotStake[stakes[user].counter].amount = stakes[user]
            .slotStake[stakes[user].counter]
            .amount
            .add(msg.value);
        stakes[user].slotStake[stakes[user].counter].startTime = uint32(
            block.timestamp
        );
        stakes[user].slotStake[stakes[user].counter].id = stakes[user].counter;

        stakes[user].counter++;
        emit Staked(
            user,
            msg.value,
            uint32(block.timestamp),
            stakes[user].counter - 1
        );
    }

    /**
     * @dev Unstake a specific amount of tokens from a specific slot
     * @param _amount The amount of tokens to be unstaked.
     * @param _slotId the id of slot from which token should be unstaked
     * @notice Unstaked tokens and rewards will be transferred to the user's address
     * @notice This is a nonReentrant function
     */
    function unstake(uint256 _amount, uint256 _slotId) public nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");
        require(_amount != 0, "invalid unstake amount specified");
        address user = msg.sender;
        require(
            stakes[user].slotStake[_slotId].amount >= _amount,
            "Insufficient staked amount"
        );

        uint256 currentReward = calculateRewards(stakes[user], _slotId);
        uint256 remainingStake = stakes[user].slotStake[_slotId].amount.sub(
            _amount
        );

        stakes[user].slotStake[_slotId].amount = remainingStake;
        stakes[user].slotStake[_slotId].startTime = uint32(block.timestamp);
        stakes[user].slotStake[_slotId].rewards = 0;

        liquidityPool.accessFunds(currentReward, "UNSTAKE");

        require(
            address(this).balance >= _amount + currentReward,
            "Contract insufficient balance"
        );
        emit Unstaked(
            user,
            _amount,
            uint32(block.timestamp),
            _slotId,
            currentReward
        );
        (bool success, ) = user.call{value: _amount + currentReward}("");
        require(success, "Unable to send value or recipient may have reverted");
    }

    /**
     * @dev Unstake all the token of user
     * @notice Unstaked all tokens and total rewards will be transferred to the user's address.
     * @notice This is a nonReentrant function
     */
    function unstakeAll() external nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");

        address user = msg.sender;

        uint256 rewards = getTotalRewards();
        uint256 stakedAmount = getUserTotalStakes();

        for (uint256 i = 0; i < stakes[user].counter; i++) {
            delete stakes[user].slotStake[i];
        }
        stakes[user].counter = 0;
        liquidityPool.accessFunds(rewards, "UNSTAKE");

        require(
            address(this).balance >= stakedAmount + rewards,
            "Contract insufficient balance"
        );
        emit UnstakedAllTokens(
            user,
            stakedAmount,
            rewards,
            uint32(block.timestamp)
        );
        (bool success, ) = user.call{value: stakedAmount + rewards}("");
        require(success, "Failed to send rewards and staked amount");
    }

    /**
     * @dev Unstake a specific amount of tokens
     * @param amount The amount of token user want to unstake
     * @notice Unstake specific amount of token and transfer unstaked tokens and rewards of those tokens to user
     * @notice this is a nonReentrant function
     */
    function unstake(uint256 amount) external nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");
        address user = msg.sender;

        require(
            amount <= getUserTotalStakes(),
            "invalid unstaking amount specified"
        );
        SlotStake storage position = stakes[user];

        uint256 i = 0;
        uint256 totalRewards = 0;

        for (i = 0; i < position.counter; i++) {
            uint256 _amount = position.slotStake[i].amount;

            if (_amount == 0) {
                continue;
            }

            uint256 rewards = calculateRewards(position, i);
            totalRewards = totalRewards.add(rewards);

            position.slotStake[i].startTime = uint32(block.timestamp);

            if (_amount > amount) {
                position.slotStake[i].amount = _amount.sub(amount);
                break;
            } else {
                delete position.slotStake[i];
                amount = amount.sub(_amount);
            }
        }
        liquidityPool.accessFunds(totalRewards, "UNSTAKE");

        require(
            address(this).balance >= amount + totalRewards,
            "Contract insufficient balance"
        );

        // use , amount -> token + rewards, timestamp, last slot, total rewards
        emit UnstakedTokens(
            user,
            amount,
            uint32(block.timestamp),
            i,
            stakes[msg.sender].slotStake[i].amount
        );
        (bool success, ) = user.call{value: amount + totalRewards}("");
        require(success, "Failed to send rewards and staked amount");
    }

    /**
     * @dev Claim a specific amount of rewards from accumulated rewards of specific slot
     * @param _rewardAmount The amount of rewards to be claimed.
     * @param _slotId The slot id from where rewards should be claimed
     * @notice Claimed rewards will be transferred to the user's address.
     * @notice This is a nonReentrant function
     */
    function claimRewards(
        uint256 _rewardAmount,
        uint256 _slotId
    ) external nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");

        address user = msg.sender;

        require(_rewardAmount > 0, "invalid amount");

        stakes[user].slotStake[_slotId].rewards = stakes[user]
            .slotStake[_slotId]
            .rewards
            .add(calculateRewards(stakes[user], _slotId));

        require(
            stakes[user].slotStake[_slotId].rewards >= _rewardAmount,
            "Insufficient rewards to claim"
        );

        stakes[user].slotStake[_slotId].rewards = stakes[user]
            .slotStake[_slotId]
            .rewards
            .sub(_rewardAmount);
        stakes[user].slotStake[_slotId].startTime = uint32(block.timestamp);

        liquidityPool.accessFunds(_rewardAmount, "CLAIM REWARDS");

        require(
            address(this).balance >= _rewardAmount,
            "Contract insufficient balance"
        );
        emit RewardClaimed(
            user,
            _rewardAmount,
            uint32(block.timestamp),
            _slotId,
            stakes[user].slotStake[_slotId].rewards
        );
        (bool success, ) = user.call{value: _rewardAmount}("");
        require(success, "Unable to send value or recipient may have reverted");
    }

    /**
     * @dev Claim all rewards from all the slots
     * @notice Transfer total rewards of user from accumulated rewards of each slot
     * @notice This is a nonReentrant function
     */

    function claimAllRewards() external nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");
        uint256 length = stakes[msg.sender].counter;
        address user = msg.sender;
        uint256 _rewardAmount = getTotalRewards();
        liquidityPool.accessFunds(_rewardAmount, "CLAIM ALL REWARDS");

        require(
            address(this).balance > _rewardAmount,
            "Contract insufficient balance"
        );
        for (uint256 i = 0; i < length; i++) {
            stakes[user].slotStake[i].rewards = 0;
            stakes[user].slotStake[i].startTime = uint32(block.timestamp);
        }
        emit AllRewardClaimed(user, _rewardAmount, uint32(block.timestamp));
        (bool success, ) = user.call{value: _rewardAmount}("");
        require(success, "Unable to send value or recipient may have reverted");
    }

    /**
     * @dev Calculate the accumulated rewards for a specific stake in a specific slot.
     * @param _stake The specific user stake data for which to calculate rewards.
     * @param _slotId The slot for which to calculate rewards
     * @return The calculated rewards for the given stake of specific slot .
     **/
    function calculateRewards(
        SlotStake storage _stake,
        uint256 _slotId
    ) internal view returns (uint256) {
        uint256 index = 0;

        uint256 rewards = 0;

        uint32 startTime = _stake.slotStake[_slotId].startTime;

        uint256 initialAmount = _stake.slotStake[_slotId].amount;

        uint256 length = apy.length;

        // example apy changing format
        // 18 -> 16 -> 14 -> 20(current)
        // here we have to find at which point user staked his assets

        if (length > 1) {
            for (uint256 i = 0; i < length; i++) {
                if (startTime <= apy[i].changeTime) {
                    index = i;
                    break;
                }
            }
            // 18 -> 16 -> (staking point of user)
            // this means that user staked after apy updated
            if (index == 0) {
                // calculate reward with current apy value
                return
                    initialAmount.mul(apy[length - 1].value).mul(
                        block.timestamp - startTime
                    ) / (10000 * frequency);
            }
            // 18-> (staking point of user) -> 16
            // this means user staked before apy updation
            else {
                for (uint256 i = index; i < length; i++) {
                    uint256 _value = initialAmount.mul(apy[i - 1].value).mul(
                        apy[i].changeTime - startTime
                    ) / (10000 * frequency);
                    // rewards.add(_value);
                    rewards += _value;
                    startTime = apy[i].changeTime;
                }
                rewards +=
                    initialAmount.mul(apy[length - 1].value).mul(
                        block.timestamp - startTime
                    ) /
                    (10000 * frequency);

                return rewards;
            }
        }
        // single apy value in array
        else {
            return
                initialAmount.mul(apy[0].value).mul(
                    block.timestamp - startTime
                ) / (10000 * frequency);
        }
    }

    /**
     * @dev Restake a specific amount of rewards of specific slot and update stake.
     * @param _amount The amount of rewards to be restaked.
     * @param _slotId The slod it of which rewards to be restaked.
     * @notice This is a nonReentrant function
     */
    function restake(uint256 _amount, uint256 _slotId) external nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");
        address user = msg.sender;

        stakes[user].slotStake[_slotId].rewards = stakes[user]
            .slotStake[_slotId]
            .rewards
            .add(calculateRewards(stakes[user], _slotId)); // Use SafeMath
        require(
            stakes[user].slotStake[_slotId].rewards >= _amount,
            "Insufficient rewards to restake"
        );

        uint256 totalStake = stakes[user].slotStake[_slotId].amount.add(
            _amount
        );

        stakes[user].slotStake[_slotId].amount = totalStake;
        stakes[user].slotStake[_slotId].startTime = uint32(block.timestamp);
        stakes[user].slotStake[_slotId].rewards = stakes[user]
            .slotStake[_slotId]
            .rewards
            .sub(_amount);

        emit ReStaked(
            user,
            _amount,
            uint32(block.timestamp),
            _slotId,
            stakes[user].slotStake[_slotId].rewards
        );
    }

    /**
     * @dev Restake a specific amount of rewards.
     * @param amount The amount of rewards to restake
     * @notice This is a nonReentrant function
     */

    function restake(uint256 amount) external nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");
        address user = msg.sender;

        uint256 totalRewards = getTotalRewards();
        require(
            amount <= totalRewards,
            "invalid amount specified for restaking"
        );
        SlotStake storage position = stakes[user];
        uint256 i = 0;
        for (i = 0; i < position.counter; i++) {
            uint256 rewardsPerSlot = position.slotStake[i].rewards.add(
                calculateRewards(stakes[user], i)
            );
            position.slotStake[i].rewards = rewardsPerSlot;
            position.slotStake[i].startTime = uint32(block.timestamp);
            // break condition where amount specified to restake is smaller than rewards in particular slot
            if (position.slotStake[i].rewards > amount) {
                position.slotStake[i].amount = position.slotStake[i].amount.add(
                    amount
                );
                position.slotStake[i].rewards = stakes[user]
                    .slotStake[i]
                    .rewards
                    .sub(amount);
                break;
            } else {
                position.slotStake[i].amount = position.slotStake[i].amount.add(
                    rewardsPerSlot
                );
                position.slotStake[i].rewards = 0;
                amount = amount.sub(rewardsPerSlot);
            }
        }

        emit ReStaked(
            user,
            amount,
            uint32(block.timestamp),
            i,
            position.slotStake[i].rewards
        );
    }

    /**
     * @dev Restake all the accumulated rewards of each slot
     * @notice this is a nonReentrant function
     */
    function restakeAll() external nonReentrant {
        require(!pause, "Please wait until the staking is unpaused");
        address user = msg.sender;

        SlotStake storage position = stakes[user];
        uint256 i = 0;
        uint256 totalAmountRestaked = 0;
        for (i = 0; i < position.counter; i++) {
            uint256 rewardsPerSlot = position.slotStake[i].rewards.add(
                calculateRewards(stakes[user], i)
            );
            totalAmountRestaked = totalAmountRestaked.add(rewardsPerSlot);
            position.slotStake[i].rewards = 0;
            position.slotStake[i].startTime = uint32(block.timestamp);
            position.slotStake[i].amount = position.slotStake[i].amount.add(
                rewardsPerSlot
            );
        }

        // TODO need to add an event here
        emit RestakedAll(user, totalAmountRestaked, uint32(block.timestamp));
    }

    /**
     * @dev Get the staked amount and start time for sender of a specific slot.
     * @param _slotId the slot id of which token amount and start time requested.
     * @return amount The amount of tokens staked.
     * @return startTime The timestamp when staking occurred.
     */
    function getUserStake(
        uint256 _slotId
    ) external view returns (uint256 amount, uint32 startTime) {
        Slot storage userStake = stakes[msg.sender].slotStake[_slotId];
        return (userStake.amount, userStake.startTime);
    }

    /**
     * @dev Get the total staked amount of sender
     **/
    function getUserTotalStakes() public view returns (uint256 amount) {
        SlotStake storage userSlotStakes = stakes[msg.sender];
        for (uint256 i = 0; i < userSlotStakes.counter; i++) {
            amount += userSlotStakes.slotStake[i].amount;
        }
    }

    /**
     * @dev Get the array of details of each slot of user
     * @return Array of detail of each slot i.e. slot id, amount staked, rewards and startTime
     */
    function getUserStakesInfo() external view returns (Slot[] memory) {
        uint256 length = stakes[msg.sender].counter;
        Slot[] memory userStakeSlots = new Slot[](length);

        for (uint256 i = 0; i < length; i++) {
            userStakeSlots[i] = stakes[msg.sender].slotStake[i];
        }
        return userStakeSlots;
    }

    /**
     * @dev Get the total accumulated rewards for sender of specific slot.
     * @param _slotId  the specific slot id of which senders rewards requested
     * @return The total amount of accumulated rewards.
     */
    function getUserRewards(uint256 _slotId) public view returns (uint256) {
        uint256 rewards = calculateRewards(stakes[msg.sender], _slotId).add(
            stakes[msg.sender].slotStake[_slotId].rewards
        ); // Use SafeMath
        return rewards;
    }

    /**
     * @dev Get the total rewards till now of sender.
     * @return total accumulated rewards of sender of each slot till now
     */
    function getTotalRewards() public view returns (uint256) {
        uint256 rewards;
        uint256 length = stakes[msg.sender].counter;
        for (uint256 i = 0; i < length; i++) {
            rewards += getUserRewards(i);
        }
        return rewards;
    }

    /**
     * @dev Get current apy
     * @return APY value
     */
    function getCurrentApy() external view returns (uint256) {
        return apy[apy.length - 1].value;
    }

    /**
     * @dev Update the staking pause status.
     * @param _pause The new staking pause status.
     * @notice This function can only be called by the contract owner.
     */
    function updateStakingPause(bool _pause) external onlyOwner {
        pause = _pause;
    }

    /**
     * @dev Set the APY (Annual Percentage Yield).
     * @param _newAPY The new APY value.
     * @notice This function can only be called by the contract owner.
     */
    function setAPY(uint16 _newAPY) external onlyOwner {
        apy.push(APY(_newAPY, uint32(block.timestamp)));
        emit ApyUpdated(_newAPY, uint32(block.timestamp));
    }

    /**
     * @dev Set the minimum USDC token
     * @param _newMinimumStake new minimum USDC stake value
     * @notice this function can only be called by the contract owner.
     */
    function setMinimumStake(uint256 _newMinimumStake) external onlyOwner {
        minimumStake = _newMinimumStake;
        emit MinimumStakeUpdated(_newMinimumStake, uint32(block.timestamp));
    }

    /**
     * @dev Set the frequency
     * @param _frequency the new frequency
     * @notice this function can only be called by the contract owner.
     */
    function setFrequency(uint256 _frequency) external onlyOwner {
        frequency = _frequency;
        emit FrequencyUpdated(_frequency, uint32(block.timestamp));
    }

    /**
     * @dev Set the liqudity pool which provides reward USDC tokens
     * @param _liquidityPool new pool address.
     * @notice this function can only be called by the contract owner.
     */
    function setLiquidityPool(address _liquidityPool) external onlyOwner {
        liquidityPool = ILiquidityPool(_liquidityPool);
        emit LiquidityPoolUpdated(_liquidityPool, uint32(block.timestamp));
    }

    /**
     * @dev Migrate funds to a new contract address.
     * @param amount The amount of funds to migrate.
     * @param newAddress The address of the new contract to receive the funds.
     * @notice This function is non-reentrant and can only be called by the contract owner.
     */
    function migration(
        uint256 amount,
        address newAddress
    ) external nonReentrant onlyOwner {
        require(
            address(this).balance >= amount,
            "Contract insufficient balance"
        );
        require(amount > 0, "invalid amount");
        require(newAddress != address(0), "invalid address");
        emit AmountMigrated(amount, newAddress, uint32(block.timestamp));
        (bool success, ) = newAddress.call{value: amount}("");
        require(success, "Unable to send value or recipient may have reverted");
    }
}
