
const DegisToken = artifacts.require("DegisToken")
const InsurancePool = artifacts.require("InsurancePool")
const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF"

module.exports = function (deployer) {
    await deployer.deploy(DegisToken)
    await deployer.deploy(InsurancePool, 100, DegisToken.address, usdcadd_rinkeby);
};