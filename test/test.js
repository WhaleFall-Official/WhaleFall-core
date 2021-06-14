const { expect } = require("chai");
const { BigNumber } = require('ethers');
const { ethers, upgrades } = require("hardhat");

const UniswapV2Factory = require('./dist/UniswapV2Factory.json');
const UniswapV2Router02 = require('./dist/UniswapV2Router02.json');
const WETH9 = require('./dist/WETH9.json');


let deployer, alice, bob, dev;
let whalefall;
let router, factory, weth, pair, pair_address;

Date.prototype.addDays = function (days) {
  var date = new Date(this.valueOf());
  date.setDate(date.getDate() + days);
  return date;
}

function milSecondsToSeconds(time) {
  return Math.round(time / 1000)
}

const basic_now = new Date();
const now = milSecondsToSeconds(basic_now);
const oneDay = milSecondsToSeconds(basic_now.addDays(1));

beforeEach(async () => {
  [deployer, alice, bob, dev] = await ethers.getSigners();

  // deploy uni
  const PancakeFactory = await ethers.getContractFactory(UniswapV2Factory.abi, UniswapV2Factory.bytecode);
  const PancakeRouter = await ethers.getContractFactory(UniswapV2Router02.abi, UniswapV2Router02.bytecode);
  const WETH = await ethers.getContractFactory(WETH9.abi, WETH9.bytecode);
  weth = await WETH.deploy()
  await weth.deployed();

  factory = await PancakeFactory.deploy(deployer.address);
  await factory.deployed();
  router = await PancakeRouter.deploy(factory.address, weth.address);
  await router.deployed();

  const WhaleFall = await ethers.getContractFactory("WhaleFall");

  whalefall = await WhaleFall.deploy(router.address);

  await whalefall.deployed();

  await  whalefall.approve(router.address,ethers.constants.MaxUint256);

})

describe("whalefall", function () {

  it("Add liquidity", async function () {

    await router.addLiquidityETH(
      whalefall.address,
      BigNumber.from("3500000000000000000000"),
      1,
      1,
      deployer.address,
      oneDay,{
        value: BigNumber.from("50000000000000000000"),
      }
    )

  })

  it("Buy Token", async function () {

    await router.addLiquidityETH(
      whalefall.address,
      BigNumber.from("3500000000000000000000"),
      1,
      1,
      deployer.address,
      oneDay,{
        value: BigNumber.from("50000000000000000000"),
      }
    )

    await router.connect(alice).swapExactETHForTokensSupportingFeeOnTransferTokens(
      1,
      [weth.address, whalefall.address],
      deployer.address,
      oneDay,
      {
        value: BigNumber.from("500000000000000000"),
      }
    )
    
  })

})