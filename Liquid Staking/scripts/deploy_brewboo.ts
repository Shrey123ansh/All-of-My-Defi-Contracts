import { ethers, run } from "hardhat"

const boo = "0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE"
const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"
const factory = "0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3"
const xboo = "0xa48d959AE2E88f1dAA7D5F611E01908106dE7598"
const usdc = "0x04068da6c83afcfa0e13ba15a6696662335d5b75"
const dai = "0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E"

async function main() {
    const brewBoo = await ethers.getContractFactory("BrewBooV3");
    const BrewBoo = await brewBoo.deploy(factory, xboo, boo, wftm, usdc, dai);
    await BrewBoo.deployed()
    console.log("BrewBoo deployed to:", BrewBoo.address);

    await run("verify:verify", {
      address: BrewBoo.address,
      constructorArguments: [factory, xboo, boo, wftm, usdc, dai],
  })
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
