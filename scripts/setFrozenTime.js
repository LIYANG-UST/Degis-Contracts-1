const InsurancePool = artifacts.require("InsurancePool");

const fs = require("fs");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const pool = await InsurancePool.at(addressList.InsurancePool);

    await pool.setFrozenTime(72000, { from: account });

    callback(true);
  } catch (e) {
    callback(e);
  }
};
