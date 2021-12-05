const PolicyFlow = artifacts.require("PolicyFlow");

module.exports = async (callback) => {
  try {
    const account = (await web3.eth.getAccounts())[0];
    console.log("user address:", account);

    const policyflow = await PolicyFlow.deployed();
    console.log("PolicyFlow address:", policyflow.address);

    // pre-set
    await policyflow.set;
  } catch (err) {
    callback(err);
  }
};
