// ---------------------------- Load the Smart Contracts -------------------------------- //
const DegisToken = artifacts.require("DegisToken");
const InsurancePool = artifacts.require("InsurancePool");
const MockUSD = artifacts.require("MockUSD");

const PolicyFlow = artifacts.require("PolicyFlow");
const PolicyToken = artifacts.require("PolicyToken");
const EmergencyPool = artifacts.require("EmergencyPool");
const FlightOracle = artifacts.require("FlightOracle");
const SigManager = artifacts.require("SigManager");
const FarmingPool = artifacts.require("FarmingPool");

// ---------------------------- Const Addresses -------------------------------- //
const degis_rinkeby = "0x6d3036117de5855e1ecd338838FF9e275009eAc2";
const usdc_rinkeby = "0xAc141573202C0c07DFE432EAa1be24a9cC97d358";

// This is my own address
const lottery_rinkeby = "0xa85D352ED54952E2C4e147B43A7D461bb395CbeE";

// Rinkeby VRF
const RINKEBY_VRF_COORDINATOR = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";

// own oracle address, jobId is inside the contract
const RINKEBY_CHAINLINK_ORACLE = "0xD68a20bf40908Bb2a4Fa1D0A2f390AA4Bd128FBB"; //dzz
const RINKEBY_LINKTOKEN = "0x01be23585060835e02b77ef475b0cc51aa1e0709";
const RINKEBY_KEYHASH =
  "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";

const buyerToken = "0x876431DAE3c10273F7B58567419eb40157CcA9Eb";

const fs = require("fs");

module.exports = async function (deployer, network) {
  if (network.startsWith("rinkeby")) {
    // await deployer.deploy(MockUSD);
    // await deployer.deploy(LPToken);
    await deployer.deploy(PolicyToken);

    await deployer.deploy(EmergencyPool);
    await deployer.deploy(
      InsurancePool,
      degis_rinkeby,
      EmergencyPool.address,
      lottery_rinkeby,
      usdc_rinkeby
    );

    await deployer.deploy(SigManager);

    await deployer.deploy(
      PolicyFlow,
      InsurancePool.address,
      PolicyToken.address,
      SigManager.address,
      buyerToken
    );

    await deployer.deploy(FlightOracle, PolicyFlow.address);

    await deployer.deploy(FarmingPool, degis_rinkeby);

    const addressList = {
      PolicyToken: PolicyToken.address,
      EmergencyPool: EmergencyPool.address,
      InsurancePool: InsurancePool.address,
      PolicyFlow: PolicyFlow.address,
      SigManager: SigManager.address,
      FlightOracle: FlightOracle.address,
      FarmingPool: FarmingPool.address,
    };

    const data = JSON.stringify(addressList, null, "\t");

    fs.writeFile("address.json", data, (err) => {
      if (err) {
        throw err;
      }
    });
    // await deployer.deploy(PolicyToken, '0x8336b18796CAb07a4897Ea0F133f214F4B5D7378')
  } else if (network.startsWith("development")) {
    await deployer.deploy(MockUSD);
    await deployer.deploy(DegisToken);
    await deployer.deploy(PolicyToken);
    await deployer.deploy(EmergencyPool);
    await deployer.deploy(
      InsurancePool,
      DegisToken.address,
      EmergencyPool.address,
      lottery_rinkeby,
      MockUSD.address
    );

    await deployer.deploy(SigManager);

    await deployer.deploy(
      PolicyFlow,
      InsurancePool.address,
      PolicyToken.address,
      SigManager.address,
      buyerToken
    );

    await deployer.deploy(FlightOracle, PolicyFlow.address);

    await deployer.deploy(FarmingPool, DegisToken.address);
  }
};
