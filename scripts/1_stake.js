const InsurancePool = artifacts.require("InsurancePool");
const usdc = artifacts.require("MockUSD");

const usdc_add = "0x4379a39c8Bd46D651eC4bdA46C32E2725b217860";

let approve_amount =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    const pool = await InsurancePool.deployed();

    const usd = await usdc.at(usdc_add);

    await usd.mint(account, web3.utils.toWei("5000", "ether"), {
      from: account,
    });

    await usd.approve(pool.address, approve_amount, { from: account });
    await pool.stake(account, web3.utils.toWei("200"), { from: account });

    const balance = await pool.getUserBalance(account);
    console.log("user balance:", balance);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
