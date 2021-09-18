// ---------------------------- Load the Smart Contracts -------------------------------- //
const DegisToken = artifacts.require("DegisToken");
const LPToken = artifacts.require('LPToken'); // only deploy once
const InsurancePool = artifacts.require("InsurancePool");
const MockUSD = artifacts.require('MockUSD');
const GetRandomness = artifacts.require('GetRandomness');
const PolicyFlow = artifacts.require('PolicyFlow');
const PolicyToken = artifacts.require('PolicyToken');  // only deploy once
const EmergencyPool = artifacts.require('EmergencyPool');

// ---------------------------- Const Addresses -------------------------------- //
const degis_rinkeby = "0xD51e2fb717A0DDC55aec9990b6F3F8B76D4922D9";
const usdc_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";
// const policy_token = "0x2aCE3BdE730B1fF003cDa21aeeA1Db33b0F04ffC";
const policy_token2 = "0xF29Ca363D07d77c1BD37986791472D7429b3a693";

// This is my own address
const lottery_rinkeby = "0x32eB34d060c12aD0491d260c436d30e5fB13a8Cd"

// Rinkeby VRF
const RINKEBY_VRF_COORDINATOR = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B'

// own oracle address, jobId is inside the contract
const RINKEBY_CHAINLINK_ORACLE = '0xD68a20bf40908Bb2a4Fa1D0A2f390AA4Bd128FBB' //dzz
const RINKEBY_LINKTOKEN = '0x01be23585060835e02b77ef475b0cc51aa1e0709'
const RINKEBY_KEYHASH = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311'


// ---------------------------- Parameters -------------------------------- //
const DEGIS_PER_BLOCK = web3.utils.toBN(10 ** 18);  // 10 degis per block

module.exports = async function (deployer, network) {
    if (network.startsWith('rinkeby')) {
        // await deployer.deploy(DegisToken)
        await deployer.deploy(LPToken)
        await deployer.deploy(EmergencyPool, usdc_rinkeby)
        await deployer.deploy(InsurancePool, 100, degis_rinkeby, EmergencyPool.address, LPToken.address, lottery_rinkeby, usdc_rinkeby, DEGIS_PER_BLOCK)
        await deployer.deploy(PolicyFlow, InsurancePool.address, policy_token2, RINKEBY_CHAINLINK_ORACLE)
        await deployer.deploy(GetRandomness, RINKEBY_VRF_COORDINATOR, RINKEBY_LINKTOKEN, RINKEBY_KEYHASH)
        // await deployer.deploy(PolicyToken, '0x8336b18796CAb07a4897Ea0F133f214F4B5D7378')
    }
    else if (network.startsWith('development')) {
        await deployer.deploy(MockUSD)
        await deployer.deploy(DegisToken)
        await deployer.deploy(LPToken)
        await deployer.deploy(EmergencyPool, MockUSD.address)
        await deployer.deploy(InsurancePool, 100, DegisToken.address, EmergencyPool.address, LPToken.address, MockUSD.address, DEGIS_PER_BLOCK)
    }
};