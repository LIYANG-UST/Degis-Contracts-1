const InsurancePool = artifacts.require("InsurancePool");
const usdc = artifacts.require("MockUSD");
const lp = artifacts.require("LPToken");

const usdc_add = "0x4379a39c8Bd46D651eC4bdA46C32E2725b217860";

const lptoken_rinkeby = "0xF5c995ca02fe83640296e36869fFBA9AF6d2b5A7";
const pool_address = "0x2A10BA07eA50d8E6CE7e2fcC0Fa86e75A0283678";

let approve_amount =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

module.exports = async (callback) => {
  try {
    const accounts = await web3.eth.getAccounts();
    const account = accounts[0];

    const pool = await InsurancePool.at(pool_address);

    const usd = await usdc.at(usdc_add);

    const lptoken = await lp.at(lptoken_rinkeby);

    console.log("pool address:", pool.address);
    const dlp = await pool.DLPToken.call();
    console.log(dlp);

    const minter = await lptoken.minter.call();
    console.log(minter);

    // 给自己mint 5000 usd
    await usd.mint(account, web3.utils.toWei("5000", "ether"), {
      from: account,
    });

    // approve最大值
    await usd.approve(pool.address, approve_amount, { from: account });

    await lptoken.passMinterRole(pool.address, { from: account });

    // stake 200 usd
    await pool.stake(account, web3.utils.toWei("200", "ether"), {
      from: account,
    });

    await pool.unstake(account, web3.utils.toWei("100", "ether"), {
      from: account,
    });

    // 查询自己的余额
    const balance = await pool.getUserBalance(account);
    console.log("user balance:", balance);

    callback(true);
  } catch (err) {
    callback(err);
  }
};
