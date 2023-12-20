# Aave Liquidity Pool Tutorial

Learn how to supply tokens to the Aave liquidity pool and earn interest in the form of passive income on your investment. We explore how to add and remove liquidity from both the UI and smart contract code. Topics covered include Aave liquidity market protocol, DeFi liquidity pools, aTokens (equity tokens), and more.

LINK address (Goerli):
0x07C725d58437504CA5f814AE406e70E21C5e8e9e

aLINK address (Goerli):
0x6A639d29454287B3cBB632Aa9f93bfB89E3fd18f

Deployed contract (Goerli):
0x903dB4fDBfDd12E2e61b20F5f0eb65b8925D0195

Deploy smart contract (Goerli):
npx hardhat run --network goerli scripts/deployMarketInteractions.js

Remix imports:
import {IPool} from "https://github.com/aave/aave-v3-core/blob/master/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "https://github.com/aave/aave-v3-core/blob/master/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "https://github.com/aave/aave-v3-core/blob/master/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
