const PolicyFlow = artifacts.require("PolicyFlow");
const USD = artifacts.require("MockUSD");
const sigManager = artifacts.require("SigManager");

const pf_address = "0x44A6F2AAC75395b2CE5338cAEE463E635EB5C005";

const sigm_add = "0xF9b59ee7DFC5176DF85fd7d5510B7Ad9Ae1D73Fc";

let approve_amount =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

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
