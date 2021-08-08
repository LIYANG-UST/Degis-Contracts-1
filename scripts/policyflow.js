const InsurancePool = artifacts.require('InsurancePool');

module.exports = async callback => {
    const pf = await InsurancePool.deployed();
    console.log('Policy Flow Address is:', pf.address);

    const tx = await pf.getPoolInfo()

    callback(tx)
}