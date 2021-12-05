const PolicyFlow = artifacts.require("PolicyFlow");
const FlightOracle = artifacts.require("FlightOracle");

const buyer_rinkeby = "0x0944729C5125576a7DB450F7F730dC5A2a1E1359";
const link_fuji = "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846";

const fs = require("fs");

module.exports = async function (deployer) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  const insurancePool_add = addressList.InsurancePool;
  const policyToken_add = addressList.FDPolicyToken;
  const sigManager_add = addressList.SigManager;

  // Deploy policyflow
  await deployer.deploy(
    PolicyFlow,
    insurancePool_add,
    policyToken_add,
    sigManager_add,
    buyer_rinkeby
  );

  addressList.PolicyFlow = PolicyFlow.address;

  // Deploy FlightOracle
  await deployer.deploy(FlightOracle, PolicyFlow.address, link_fuji);

  addressList.FlightOracle = FlightOracle.address;

  // Write back the addresslist
  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
