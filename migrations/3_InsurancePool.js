const InsurancePool = artifacts.require("InsurancePool")

module.exports = function (deployer) {
    deployer.deploy(InsurancePool);
};