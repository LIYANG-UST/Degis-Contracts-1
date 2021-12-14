const FarmingPool = artifacts.require("FarmingPool");

const fs = require("fs");

const pool = "0x7C824EC3eff695ffbBBb44410144fDeB00862A69";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const farmingpool = await FarmingPool.at(pool);

    const fd_lptoken = addressList.InsurancePool;

    const degisPerBlock = web3.utils.toWei("5", "ether");

    const poolList = await farmingpool.getPoolList();
    console.log(poolList);

    // await farmingpool.add(fd_lptoken, degisPerBlock, false, { from: account });

    // const BTC24000 = "0x4e08F008B363a9219F3D9157c2D82BcBDf678E41";
    // const BTC71000 = "0xaBD91ccE8413f5612e28Abdf70B540E01A08cf70";
    // const ETH2000 = "0xF2073C1a56e3Be7e07075D9d615f637e4E0937E8";
    // const ETH5900 = "0xd6bC9D213FF927deFd06ac8610b10b4775dE1D0e";
    // const AVAX60 = "0x4773232f6B109745d7133dD08394F6B3f947b4B0";
    // const AVAX100 = "0x124Da3EB4E9306B5A0232c06989a96E8a0a4B710";

    await farmingpool.setDegisReward(5, degisPerBlock, false);

    await farmingpool.setDegisReward(6, degisPerBlock, false);

    await farmingpool.setDegisReward(7, degisPerBlock, false);
    await farmingpool.setDegisReward(8, degisPerBlock, false);
    await farmingpool.setDegisReward(9, degisPerBlock, false);
    await farmingpool.setDegisReward(10, degisPerBlock, true);

    callback(true);
  } catch (e) {
    callback(e);
  }
};
