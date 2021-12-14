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

    // await farmingpool.add(fd_lptoken, degisPerBlock, false, { from: account });

    const BTC25000 = "0xDC8713eD67FA2E142E16Cb836Fc5610c87e5dF95";
    const BTC75000 = "0xD9447A2aaaBc8DEED90eacf265e37c53aDADF481";
    const ETH2000 = "0x1C6B2D89E6F7c4ae3f7A31e50cF9aa802fd95CC6";
    const ETH6000 = "0x39c85Ac4d376c19af3764fc67DB8B0F80D03ab2e";
    const AVAX65 = "0xde02b8b6828783C4178E9af1cD96db50aaF584E2";
    const AVAX106 = "0xdb6F149FC1ae56DB2b565C88a58da7f4284A65d4";

    await farmingpool.add(BTC25000, degisPerBlock, false);

    await farmingpool.add(BTC75000, degisPerBlock, true);

    await farmingpool.add(ETH2000, degisPerBlock, false);
    await farmingpool.add(ETH6000, degisPerBlock, false);
    await farmingpool.add(AVAX65, degisPerBlock, false);
    await farmingpool.add(AVAX106, degisPerBlock, false);

    callback(true);
  } catch (e) {
    callback(e);
  }
};
