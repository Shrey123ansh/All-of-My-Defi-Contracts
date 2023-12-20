const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { fundContract } = require("../utils/utilities");

const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");

const provider = waffle.provider;

describe("FlashLoan Contract", () => {
  let FLASHLOAN,
    BORROW_AMOUNT,
    FUND_AMOUNT,
    initialFundingHuman,
    txArbitrage;


  const DECIMALS = 18;

  const BUSD_WHALE = "0xf977814e90da44bfa03b6295a0616a897441acec";
  const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
  const CAKE = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82";
  const CROX = "0x2c094F5A7D1146BB93850f629501eB749f6Ed491";


  const busdInstance = new ethers.Contract(BUSD, abi, provider);

  beforeEach(async () => {

    // Ensure that the WHALE has a balance
    const whale_balance = await provider.getBalance(BUSD_WHALE);
    expect(whale_balance).not.equal("0");

    // Deploy smart contract
    const FlashLoan = await ethers.getContractFactory("FlashLoan");
    FLASHLOAN = await FlashLoan.deploy();
    await FLASHLOAN.deployed();

    const borrowAmountHuman = "1";
    BORROW_AMOUNT = ethers.utils.parseUnits(borrowAmountHuman, DECIMALS);

    initialFundingHuman = "100";
    FUND_AMOUNT = ethers.utils.parseUnits(initialFundingHuman, DECIMALS);

    // Fund our Contract - FOR TESTING ONLY
    await fundContract(
      busdInstance,
      BUSD_WHALE,
      FLASHLOAN.address,
      initialFundingHuman
    );
  });

  describe("Arbitrage Execution", () => {
    it("ensures the contract is funded", async () => {
      const flashLoanBalance = await FLASHLOAN.getBalanceOfToken(
        BUSD
      );

      const flashSwapBalanceHuman = ethers.utils.formatUnits(
        flashLoanBalance,
        DECIMALS
      );
      expect(Number(flashSwapBalanceHuman)).equal(Number(initialFundingHuman));
    });

    it("executes the arbitrage", async () => {
      txArbitrage = await FLASHLOAN.initateArbitrage(
        BUSD,
        BORROW_AMOUNT
      );

      assert(txArbitrage);

      // Print balances
      const contractBalanceBUSD = await FLASHLOAN.getBalanceOfToken(BUSD);
      const formattedBalBUSD = Number(
        ethers.utils.formatUnits(contractBalanceBUSD, DECIMALS)
      );
      console.log("Balance of BUSD: " + formattedBalBUSD);

      const contractBalanceCROX = await FLASHLOAN.getBalanceOfToken(CROX);
      const formattedBalCROX = Number(
        ethers.utils.formatUnits(contractBalanceCROX, DECIMALS)
      );
      console.log("Balance of CROX: " + formattedBalCROX);

      const contractBalanceCAKE = await FLASHLOAN.getBalanceOfToken(CAKE);
      const formattedBalCAKE = Number(
        ethers.utils.formatUnits(contractBalanceCAKE, DECIMALS)
      );
      console.log("Balance of CAKE: " + formattedBalCAKE);
    });
  });
});