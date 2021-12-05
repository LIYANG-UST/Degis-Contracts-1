const EmergencyPool = artifacts.require("EmergencyPool");

const fs = require("fs");

module.exports = async function (deployer) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  await deployer.deploy(EmergencyPool);

  addressList.EmergencyPool = EmergencyPool.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
