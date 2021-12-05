const SigManager = artifacts.require("SigManager");

const fs = require("fs");

module.exports = async function (deployer, network) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  await deployer.deploy(SigManager);

  addressList.SigManager = SigManager.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
