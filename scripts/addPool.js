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

    const degisPerBlock = web3.utils.toWei("1", "ether");

    // await farmingpool.add(fd_lptoken, degisPerBlock, false, { from: account });

    const BTC30000L202101 = "0x36a0952518a5bF9Edf70C406eFb238Ff699f9019";
    const ETH2000L202101 = "0xD464B7fed9c740594409969979266832d3508372";
    const AVAX30L202101 = "0xADF20fdd2026124E9a6b16481B32e249393f3e4B";

    await farmingpool.add(BTC30000L202101, degisPerBlock, false);

    await farmingpool.add(AVAX30L202101, degisPerBlock, true);

    await farmingpool.add(ETH2000L202101, degisPerBlock, false);

    callback(true);
  } catch (e) {
    callback(e);
  }
};
