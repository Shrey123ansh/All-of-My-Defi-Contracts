import { task } from "hardhat/config"
import "dotenv/config"
import "ethers"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-solhint"
import "@nomiclabs/hardhat-ethers"
import "hardhat-abi-exporter"
import "solidity-coverage"
import { HardhatUserConfig } from "hardhat/types"
import "hardhat-gas-reporter"

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const accounts = {
  mnemonic: process.env.MNEMONIC || "test test test test test test test test test test test junk",
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  mocha: {
    timeout: 20000,
  },
  etherscan: {
    apiKey: process.env.FTMSCAN_API_KEY
  },
  networks: {
    hardhat: {
      accounts,
      forking: {
        url: "https://rpc.fantom.network",
        blockNumber: 34649573,
      }
    },
    localhost: {
      accounts,
      gasPrice: 20000000000,
    },
    fantom: {
      url: "https://rpc.ftm.tools",
      accounts,
      chainId: 250,
      gasPrice: 200000000000,
    },
    "fantom-testnet": {
      url: "https://rpc.testnet.fantom.network",
      accounts,
      chainId: 4002,
      gasMultiplier: 2,
    },
  },
  solidity: {   
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      },
    ],
  },
}
export default config
