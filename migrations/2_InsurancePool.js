
const DegisToken = artifacts.require("DegisToken");
const InsurancePool = artifacts.require("InsurancePool");
const MockUSD = artifacts.require('MockUSD');
const GetFlightData = artifacts.require('GetFlightData')
const PolicyFlow = artifacts.require('PolicyFlow');
const degis_rinkeby = "0xB4Ae3FB3a1AC2Be65aCC37C40727B5EEaC93A93a";
const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";
const RINKEBY_VRF_COORDINATOR = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B'
const RINKEBY_LINKTOKEN = '0x01be23585060835e02b77ef475b0cc51aa1e0709'
const RINKEBY_KEYHASH = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311'
const DEGIS_PER_BLOCK = 10;

module.exports = async function (deployer, network) {
    if (network.startsWith('rinkeby')) {
        await deployer.deploy(InsurancePool, 100, degis_rinkeby, usdcadd_rinkeby, DEGIS_PER_BLOCK)
        await deployer.deploy(PolicyFlow, InsurancePool.address, RINKEBY_VRF_COORDINATOR)
        await deployer.deploy(GetFlightData, RINKEBY_VRF_COORDINATOR, RINKEBY_LINKTOKEN, RINKEBY_KEYHASH)
    }
    else if (network.startsWith('development')) {
        await deployer.deploy(MockUSD)
        await deployer.deploy(DegisToken)
        await deployer.deploy(InsurancePool, 100, DegisToken.address, MockUSD.address)
    }
};