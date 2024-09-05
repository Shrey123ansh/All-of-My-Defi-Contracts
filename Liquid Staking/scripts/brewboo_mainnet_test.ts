import { ethers, run } from "hardhat"

const boo = "0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE"
const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"
const factory = "0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3"
const xboo = "0xa48d959AE2E88f1dAA7D5F611E01908106dE7598"
const usdc = "0x04068da6c83afcfa0e13ba15a6696662335d5b75"
const dai = "0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E"

async function main() {
    let accounts = await ethers.getSigners();
    let provider = await ethers.provider
    let tx

    const brewBoo = await ethers.getContractFactory("BrewBooV3");
    const BrewBoo = await brewBoo.deploy(factory, xboo, boo, wftm, usdc, dai);
    const Boo = await ethers.getContractAt("contracts/interfaces/IERC20.sol:IERC20", boo)
    await BrewBoo.deployed()
    console.log("BrewBoo deployed to:", BrewBoo.address);

    console.log("User Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(accounts[0].address)))
    console.log("xboo Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(xboo)))

    let puppet = "0x7495f066bb8a0f71908deb8d4efe39556f13f58a"
    let LP = "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c"
    //*
    //const provider = new ethers.providers.JsonRpcProvider( "http://127.0.0.1:8545/" );
    await provider.send("hardhat_impersonateAccount", [puppet]);
    let spooky = provider.getSigner(puppet);
    let token = await ethers.getContractAt("contracts/interfaces/IERC20.sol:IERC20", LP)
    await token.connect(spooky).transfer(BrewBoo.address, ethers.utils.parseEther("0.0001"))
    await provider.send("hardhat_stopImpersonatingAccount", [puppet]);
    /**/


    tx = await BrewBoo.convertMultiple([wftm], [usdc], [])
    console.log("*buyback* - gas used: ", (await tx.wait()).gasUsed)
    console.log("User Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(accounts[0].address)))
    console.log("xboo Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(xboo)))

    for(let i = 0; i < 3; i++) {
        puppet = "0x67fc8c432448f9a8d541c17579ef7a142378d5ad"
        LP = "0x0a80C53AfC6DE9dfB2017781436BfE5090F4aCB4"
        //*
        await provider.send("hardhat_impersonateAccount", [puppet]);
        spooky = provider.getSigner(puppet);
        token = await ethers.getContractAt("contracts/interfaces/IERC20.sol:IERC20", LP)
        if(i != 2)
            await token.connect(spooky).transfer(BrewBoo.address, ethers.utils.parseEther("0.01"))
        await provider.send("hardhat_stopImpersonatingAccount", [puppet]);
        /**/

        console.log("Last route: ", await BrewBoo.lastRoute("0x2f6f07cdcf3588944bf4c42ac74ff24bf56e7590"))
        //await BrewBoo.setBridge("0x2f6f07cdcf3588944bf4c42ac74ff24bf56e7590", usdc)
        if(i == 0)
            tx = await BrewBoo.convertMultiple([usdc], ["0x2f6f07cdcf3588944bf4c42ac74ff24bf56e7590"], [])
        else if(i == 1)
            tx = await BrewBoo.convertMultiple([usdc], ["0x2f6f07cdcf3588944bf4c42ac74ff24bf56e7590"], [ethers.utils.parseEther("0.005")])
        else if(i == 2)
            tx = await BrewBoo.convertMultiple([usdc], ["0x2f6f07cdcf3588944bf4c42ac74ff24bf56e7590"], [])
        console.log("*buyback* - gas used: ", (await tx.wait()).gasUsed)
        console.log("Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(accounts[0].address)))
        console.log("xboo Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(xboo)))
    }


    puppet = "0x7495f066bb8a0f71908deb8d4efe39556f13f58a"
    LP = "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c"
    //*
    await provider.send("hardhat_impersonateAccount", [puppet]);
    spooky = provider.getSigner(puppet);
    token = await ethers.getContractAt("contracts/interfaces/IERC20.sol:IERC20", LP)
    await token.connect(spooky).transfer(BrewBoo.address, ethers.utils.parseEther("0.0001"))
    await provider.send("hardhat_stopImpersonatingAccount", [puppet]);
    /**/

        puppet = "0x67fc8c432448f9a8d541c17579ef7a142378d5ad"
        LP = "0x0a80C53AfC6DE9dfB2017781436BfE5090F4aCB4"
        //*
        await provider.send("hardhat_impersonateAccount", [puppet]);
        spooky = provider.getSigner(puppet);
        token = await ethers.getContractAt("contracts/interfaces/IERC20.sol:IERC20", LP)
        await token.connect(spooky).transfer(BrewBoo.address, ethers.utils.parseEther("0.01"))
        await provider.send("hardhat_stopImpersonatingAccount", [puppet]);
        /**/

        console.log("DOUBLE BUYBACK")

        tx = await BrewBoo.convertMultiple([usdc, wftm], ["0x2f6f07cdcf3588944bf4c42ac74ff24bf56e7590", usdc], [])
        console.log("*buyback* - gas used: ", (await tx.wait()).gasUsed)
        console.log("Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(accounts[0].address)))
        console.log("xboo Boo balance: ", ethers.utils.formatEther(await Boo.balanceOf(xboo)))







}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
