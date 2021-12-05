const sigManager = artifacts.require("SigManager");

const fs = require("fs");

const account1 = "0x32eB34d060c12aD0491d260c436d30e5fB13a8Cd";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];
    console.log("my account:", account);

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const sigm = await sigManager.at(addressList.SigManager);

    await sigm.addSigner(account1, { from: account });

    callback(true);
  } catch (err) {
    callback(err);
  }
};
