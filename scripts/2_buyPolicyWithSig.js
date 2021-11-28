const PolicyFlow = artifacts.require("PolicyFlow");
const USD = artifacts.require("MockUSD");
const sigManager = artifacts.require("SigManager");

const pf_address = "0x44A6F2AAC75395b2CE5338cAEE463E635EB5C005";

const sigm_add = "0x271eb8Bcdbe92c1FD2cbAf0f5dC9A5f11D8055a4";

let approve_amount =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    const policyflow = await PolicyFlow.at(pf_address);

    const sigm = await sigManager.at(sigm_add);

    await sigm.addSigner(account, { from: account });

    let date = new Date().getTime();
    date = parseInt(date / 1000);

    const _SUBMIT_CLAIM_TYPEHASH = web3.utils.soliditySha3(
      "DegisSubmitClaim(uint256 policyOrder,uint256 premium,uint256 payoff)"
    );
    const flightNumber = "AQ1299";
    const premium = web3.utils.toWei("10", "ether");

    const deadline = date + 3000;

    const hasedInfo = web3.utils.soliditySha3(
      _SUBMIT_CLAIM_TYPEHASH,
      flightNumber,
      premium,
      deadline
    );

    console.log(hasedInfo);

    const signature = await web3.eth.sign(hasedInfo, account);

    console.log("sig:", signature);

    const tx = await policyflow.newApplication(
      0,
      flightNumber,
      premium,
      date + 6000000,
      date + 6100000,
      deadline,
      web3.utils.toHex(signature),
      { from: account }
    );

    console.log(tx.tx);

    const user_policy = await policyflow.viewUserPolicy(account, {
      from: account,
    });

    console.log("user policy:", user_policy);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
