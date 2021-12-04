const FarmingPool = artifacts.require("FarmingPool");

require("chai").use(require("chai-as-promised")).should();

contract("FarmingPool", async ([deployer, user1, user2]) => {
  let farmingPool;
  before(async () => {
    farmingPool = await FarmingPool.deployed();
    console.log(farmingPool.address);
  });

  it("should have an owner", async () => {
    const owner = await farmingPool.owner.call();
    assert.equal(owner, deployer);
  });
});
