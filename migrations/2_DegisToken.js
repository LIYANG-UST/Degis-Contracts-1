const DegisToken = artifacts.require("DegisToken")

module.exports = function(deployer) {
    deployer.deploy(DegisToken);
};