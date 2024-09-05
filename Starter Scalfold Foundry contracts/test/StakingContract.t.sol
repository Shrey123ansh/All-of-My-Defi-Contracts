// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/StakingContract.sol";
import "openzeppelin/utils/math/SafeMath.sol";
import "../contracts/LiquidityPool.sol";

contract StakingTest is Test {
    StakingContract stakingContract;
    LiquidityPool liquidityPool;

    using SafeMath for uint256;

    function setUp() public {
        // _apy = 18
        // _minimumStakingTokens = 100 USDC
        // frequency = 365 days

        liquidityPool = new LiquidityPool();
        vm.deal(address(liquidityPool), 100);

        // stakingContract = new StakingContract(
        //     18,
        //     100000000000000000000,
        //     31536000,
        //     address(liquidityPool)
        // );
        stakingContract = new StakingContract();
    }

    function test_StakingUSDC(address user) public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);
        stakingContract.stake{value: 100 ether}();
        (uint256 amount, uint256 startTime) = stakingContract.getUserStake(0);
        assertEq(amount, 100 ether);
        assertEq(startTime, block.timestamp);
        vm.stopPrank();
    }

    function test_StakingInSlot(address user) public {
        vm.startPrank(user);
        vm.deal(user, 10000 ether);

        for (uint16 i = 0; i < 100; i++) {
            stakingContract.stake{value: 100 ether}();
            (uint256 amount, uint256 startTime) = stakingContract.getUserStake(
                i
            );
            assertEq(amount, 100 ether);
            assertEq(startTime, block.timestamp);
            vm.warp(i + 2);
        }

        assertEq(address(stakingContract).balance, 10000 ether);
        vm.stopPrank();
    }

    function test_StakeAndUnstake(address user) public {
        vm.startPrank(user);
        vm.deal(user, 10000 ether);

        for (uint16 i = 0; i < 100; i++) {
            stakingContract.stake{value: 100 ether}();
            (uint256 amount, uint256 startTime) = stakingContract.getUserStake(
                i
            );
            assertEq(amount, 100 ether);
            assertEq(startTime, block.timestamp);
            vm.warp(i + 2);
        }
        assertEq(address(stakingContract).balance, 10000 ether);

        for (uint16 i = 0; i < 100; i++) {
            stakingContract.unstake(100 ether, i);
        }

        // user gets his complete stake amount of all slots
        assertEq(user.balance, 10000 ether);

        vm.stopPrank();
    }

    function test_StakeAndClaimReward() public {
        address user = address(123);
        vm.startPrank(user);
        vm.deal(user, 100 ether);

        stakingContract.stake{value: 100 ether}();
        (uint256 amount, uint256 startTime) = stakingContract.getUserStake(0);
        assertEq(amount, 100 ether);
        assertEq(startTime, block.timestamp);
        console.log(user.balance);
        // changing block.timestamp to 1000 from 1
        vm.warp(1000);

        // as we make only 1 stake so the slot id would be zero
        uint256 rewards = stakingContract.getUserRewards(0);
        stakingContract.claimRewards(rewards, 0);
        assertEq(user.balance, rewards);

        vm.stopPrank();
    }

    function test_StakeAndRestakeReward(address user) public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);

        stakingContract.stake{value: 100 ether}();
        (uint256 amount, uint256 startTime) = stakingContract.getUserStake(0);
        assertEq(amount, 100 ether);
        assertEq(startTime, block.timestamp);

        // changing block.timestamp to 1000 from 1
        vm.warp(1000);

        // as we make only 1 stake so the slot id would be zero
        uint256 rewards = stakingContract.getUserRewards(0);
        stakingContract.restake(rewards, 0);
        (uint256 restakeAmount, uint256 restakeStartTime) = stakingContract
            .getUserStake(0);
        assertEq(restakeAmount, amount + rewards);
        assertEq(restakeStartTime, block.timestamp);

        vm.stopPrank();
    }

    function test_StakeAndRewardsTime(address user) public {
        vm.startPrank(user);
        vm.deal(user, 200 ether);

        // first stake at time stamp - 1
        stakingContract.stake{value: 100 ether}();
        (uint256 amount, uint256 startTime) = stakingContract.getUserStake(0);
        assertEq(amount, 100 ether);
        assertEq(startTime, block.timestamp);

        // changing block.time to 1000
        vm.warp(1000);

        //    restaking at block.timestamp 1000
        uint256 rewards = stakingContract.getUserRewards(0);
        stakingContract.restake(rewards, 0);
        (uint256 restakeAmount, uint256 restakeStartTime) = stakingContract
            .getUserStake(0);
        assertEq(restakeAmount, amount + rewards);
        assertEq(restakeStartTime, block.timestamp);

        // changing block.timestamp to 2000
        vm.warp(3000);
        // staking agian
        stakingContract.stake{value: 100 ether}();
        (uint256 amountSlot2, uint256 startTimeSlot2) = stakingContract
            .getUserStake(1);
        assertEq(amountSlot2, 100 ether);
        assertEq(startTimeSlot2, block.timestamp);

        // restaking the rewards of slot 1 at block.timestamp 3000
        uint256 rewardsBlockTime3000 = stakingContract.getUserRewards(0);
        stakingContract.restake(rewardsBlockTime3000, 0);
        (uint256 restakeAmountSlot1, ) = stakingContract.getUserStake(0);
        assertEq(restakeAmountSlot1, amount + rewards + rewardsBlockTime3000);

        assertEq(address(stakingContract).balance, 200 ether);

        vm.stopPrank();
    }

    function test_Time(address user) public {
        vm.startPrank(user);

        uint256 totalRewards;

        for (uint i = 0; i < 100; i++) {
            vm.deal(user, 100 ether);

            // first stake at time stamp - 1
            stakingContract.stake{value: 100 ether}();
            (uint256 amount, uint256 startTime) = stakingContract.getUserStake(
                i
            );
            assertEq(amount, 100 ether);
            assertEq(startTime, block.timestamp);

            vm.warp(i + 1000);
            uint256 rewards = stakingContract.getUserRewards(i);
            totalRewards += rewards;
            stakingContract.restake(rewards, i);
            (uint256 restakeAmount, uint256 restakeStartTime) = stakingContract
                .getUserStake(i);
            assertEq(restakeAmount, amount + rewards);
            assertEq(restakeStartTime, block.timestamp);
        }
        uint256 totalAmount = stakingContract.getUserTotalStakes();
        uint256 baseAmount = 100 * 100 ether;
        assertEq(totalAmount, baseAmount + totalRewards);
        vm.stopPrank();
    }

    function test_DynamicAPY(address user) public {
        vm.deal(user, 1000 ether);
        vm.warp(100);

        vm.startPrank(user);
        stakingContract.stake{value: 100 ether}();
        (uint256 amount, uint256 startTime) = stakingContract.getUserStake(0);
        assertEq(amount, 100 ether);
        assertEq(startTime, block.timestamp);
        vm.stopPrank();

        vm.warp(1000);

        stakingContract.setAPY(16);

        vm.warp(4000);

        stakingContract.setAPY(14);

        vm.warp(12000);

        stakingContract.setAPY(20);

        vm.warp(16000);
        vm.startPrank(user);

        uint256 rewards = stakingContract.getUserRewards(0);

        (uint16 apy1, ) = stakingContract.apy(0);
        (uint16 apy2, ) = stakingContract.apy(1);
        (uint16 apy3, ) = stakingContract.apy(2);
        (uint16 apy4, ) = stakingContract.apy(3);

        uint initialAmount = 100000000000000000000;
        uint256 calculatedRewards;
        calculatedRewards +=
            (initialAmount.mul(apy1).mul(1000 - 100)) /
            (10000 * 365 days);
        calculatedRewards +=
            (initialAmount.mul(apy2).mul(4000 - 1000)) /
            (10000 * 365 days);
        calculatedRewards +=
            (initialAmount.mul(apy3).mul(12000 - 4000)) /
            (10000 * 365 days);
        calculatedRewards +=
            (initialAmount.mul(apy4).mul(16000 - 12000)) /
            (10000 * 365 days);

        assertEq(rewards, calculatedRewards);
        vm.stopPrank();
    }
}
