const FarmingPool = artifacts.require("FarmingPool");

// ---------------------------- Const Addresses -------------------------------- //
const degis_rinkeby = "0x0f799713D3C34f1Cbf8E1530c53e58a59D9F6872";

const fs = require("fs");

module.exports = async function (deployer, network) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  await deployer.deploy(FarmingPool, degis_rinkeby);

  addressList.FarmingPool = FarmingPool.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
