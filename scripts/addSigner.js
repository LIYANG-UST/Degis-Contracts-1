const sigManager = artifacts.require("SigManager");

const sigm_add = "0x32F73De8c7236a0f50f1Cd05349879caD0cBfA9a";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    const sigm = await sigManager.at(sigm_add);

    await sigm.addSigner(account, { from: account });

    callback(true);
  } catch (err) {
    callback(err);
  }
};
