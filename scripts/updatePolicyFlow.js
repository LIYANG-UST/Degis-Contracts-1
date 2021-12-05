const FDPolicyToken = artifacts.require("FDPolicyToken");
const PolicyFlow = artifacts.require("PolicyFlow");
const InsurancePool = artifacts.require("InsurancePool");

const fs = require("fs");

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    const addressList = JSON.parse(fs.readFileSync("address.json"));

    const pool = await InsurancePool.at(addressList.InsurancePool);

    const policyflow = await PolicyFlow.at(addressList.PolicyFlow);
    const policytoken = await FDPolicyToken.at(addressList.FDPolicyToken);

    await policytoken.updatePolicyFlow(policyflow.address, { from: account });

    await pool.setPolicyFlow(policyflow.address, { from: account });

    callback(true);
  } catch (e) {
    callback(e);
  }
};
