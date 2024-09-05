//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/StakingContract.sol";
import "../contracts/LiquidityPool.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";


contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);
    error InvalidOwnerAddress();

    StakingContract stakingContract;
    LiquidityPool liquidityPool;


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        uint256 owner = vm.envUint("OWNER_ADDRESS");
        address admin = vm.addr(deployerPrivateKey);

        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }
        if (owner == 0) {
            revert InvalidOwnerAddress();
        }
        vm.startBroadcast(deployerPrivateKey);
        address setter = vm.addr(deployerPrivateKey);
        _staking(admin, owner);
        vm.stopBroadcast();
        exportDeployments();
    }


        function _staking(address admin, uint256 owner) internal {
            liquidityPool = new LiquidityPool();

            liquidityPoolProxy = new TransparentUpgradeableProxy(
                address(liquidityPool),
                admin,
                abi.encodeWithSignature(
                    "initialize(address)",
                    address(uint160(owner))
                )
            );

            stakingContract = new StakingContract();

            /**
             * _apy = 18%
             * minimum stake amount =  1 USDC
             * frequency = 31536000
             * liquidity pool contract address = address(liquidityPoolProxy)
             */

            stakingContractProxy = new TransparentUpgradeableProxy(
                address(stakingContract),
                admin,
                abi.encodeWithSignature(
                    "initialize(uint16,uint256,uint256,address,address)",
                    18,
                    1000000000000000000,
                    31536000,
                    address(liquidityPoolProxy),
                    address(uint160(owner))
                )
            );

            console.logString(
                string.concat(
                    "staking contract deployed at: ",
                    vm.toString(address(stakingContractProxy))
                )
            );
            console.logString(
                string.concat(
                    "balance of liquidity : ",
                    vm.toString(address(liquidityPoolProxy).balance)
                )
            );
            console.logString(
                string.concat(
                    "liquidity pool contract at: ",
                    vm.toString(address(liquidityPoolProxy))
                )
            );
        }
}
