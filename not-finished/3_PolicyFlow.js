const GetFlightData = artifacts.require('GetFlightData')
const InsurancePool = artifacts.require('InsurancePool')
const PolicyFlow = artifacts.require('PolicyFlow')

// const { LinkToken } = require('@chainlink/contracts/truffle/v0.4/LinkToken')
// const _InsurancePool = require('./2_InsurancePool')
const RINKEBY_VRF_COORDINATOR = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B'
// const RINKEBY_LINKTOKEN = '0x01be23585060835e02b77ef475b0cc51aa1e0709'
// const RINKEBY_KEYHASH = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311'

module.exports = async (deployer, network, [defaultAccount]) => {

    // LinkToken.setProvider(deployer.provider)
    // GetFlightData.setProvider(deployer.provider)
    if (network.startsWith('rinkeby')) {
        // await deployer.deploy(GetFlightData, RINKEBY_VRF_COORDINATOR, RINKEBY_LINKTOKEN, RINKEBY_KEYHASH)
        // let dnd = await GetFlightData.deployed()
        await deployer.deploy(PolicyFlow, InsurancePool.deployed().address, RINKEBY_VRF_COORDINATOR)

    } else if (network.startsWith('mainnet')) {
        console.log("If you're interested in early access to Chainlink VRF on mainnet, please email vrf@chain.link")
    } else {
        console.log("Right now only rinkeby works! Please change your network to Rinkeby")
        // await deployer.deploy(DungeonsAndDragonsCharacter)
        // let dnd = await DungeonsAndDragonsCharacter.deployed()
    }
}
