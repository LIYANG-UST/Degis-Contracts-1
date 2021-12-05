const InsurancePool = artifacts.require("InsurancePool");

const degis_add = "0x0f799713D3C34f1Cbf8E1530c53e58a59D9F6872";

const lottery_rinkeby = "0xF0F661C2Ad10192012F827816C357574Ce4e0ECb";

const usdc_rinkeby = "0xF886dDc935E8DA5Da26f58f5D266EFdfDA1AD260";

const fs = require("fs");
module.exports = async function (deployer) {
  const addressList = JSON.parse(fs.readFileSync("address.json"));

  const EmergencyPool_add = addressList.EmergencyPool;

  await deployer.deploy(
    InsurancePool,
    degis_add,
    EmergencyPool_add,
    lottery_rinkeby,
    usdc_rinkeby
  );

  addressList.InsurancePool = InsurancePool.address;

  fs.writeFileSync("address.json", JSON.stringify(addressList, null, "\t"));
};
