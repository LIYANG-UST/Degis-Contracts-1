const FarmingPool = artifacts.require("FarmingPool");

const degis_rinkeby = "0x0C970444856f143728e791fbfC3b5f6AD7f417Dd";

module.exports = function (deployer) {
  deployer.deploy(FarmingPool, degis_rinkeby);
};
