
const DegisToken = artifacts.require("DegisToken");
const InsurancePool = artifacts.require("InsurancePool");
const MockUSD = artifacts.require('MockUSD');
const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";
const DEGIS_PER_BLOCK = 10;

module.exports = async function (deployer, network) {
    if (network.startsWith('rinkeby')) {
        await deployer.deploy(DegisToken)
        await deployer.deploy(InsurancePool, 100, DegisToken.address, usdcadd_rinkeby, DEGIS_PER_BLOCK)
    }
    else if (network.startsWith('development')) {
        await deployer.deploy(MockUSD)
        await deployer.deploy(DegisToken)
        await deployer.deploy(InsurancePool, 100, DegisToken.address, MockUSD.address)
    }
};