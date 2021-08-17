
const DegisToken = artifacts.require("DegisToken");
const InsurancePool = artifacts.require("InsurancePool");
const MockUSD = artifacts.require('MockUSD');
const GetFlightData = artifacts.require('GetFlightData');
const PolicyFlow = artifacts.require('PolicyFlow');
const PolicyToken = artifacts.require('PolicyToken');

const degis_rinkeby = "0xa5DaDD05F67996EC2428d07f52C9D3852F18c759";
const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";
const policy_token = "0x2aCE3BdE730B1fF003cDa21aeeA1Db33b0F04ffC";
const RINKEBY_VRF_COORDINATOR = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B'
// const RINKEBY_CHAINLINK_ORACLE = '0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e'
const RINKEBY_CHAINLINK_ORACLE = '0xD68a20bf40908Bb2a4Fa1D0A2f390AA4Bd128FBB' //dzz
// const RINKEBY_JOBID = '8cd6d6cad1ed43e99829746a6da7fb59' //dzz
const RINKEBY_JOBID = "6d1bfe27e7034b1d87b5270556b17277"

const RINKEBY_LINKTOKEN = '0x01be23585060835e02b77ef475b0cc51aa1e0709'
const RINKEBY_KEYHASH = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311'
const DEGIS_PER_BLOCK = web3.utils.toBN(10 ** 18);

module.exports = async function (deployer, network) {
    if (network.startsWith('rinkeby')) {
        // await deployer.deploy(DegisToken)
        await deployer.deploy(InsurancePool, 50, degis_rinkeby, usdcadd_rinkeby, DEGIS_PER_BLOCK)
        await deployer.deploy(PolicyFlow, InsurancePool.address, policy_token, RINKEBY_CHAINLINK_ORACLE)
        await deployer.deploy(GetFlightData, RINKEBY_VRF_COORDINATOR, RINKEBY_LINKTOKEN, RINKEBY_KEYHASH)
        // await deployer.deploy(PolicyToken, PolicyFlow.address)
    }
    else if (network.startsWith('development')) {
        await deployer.deploy(MockUSD)
        await deployer.deploy(DegisToken)
        await deployer.deploy(InsurancePool, 100, DegisToken.address, MockUSD.address, DEGIS_PER_BLOCK)
    }
};