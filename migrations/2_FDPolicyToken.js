const FDPolicyToken = artifacts.require("FDPolicyToken");

const fs = require("fs");

module.exports = async function (deployer) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  await deployer.deploy(FDPolicyToken);

  addressList.FDPolicyToken = FDPolicyToken.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
