// Contract ABIs
const InsurancePool = artifacts.require('InsurancePool');
const PolicyFlow = artifacts.require('PolicyFlow')
const MockUSD = artifacts.require('MockUSD')
const PolicyToken = artifacts.require('PolicyToken')
const DegisToken = artifacts.require('DegisToken')
const LinkTokenInterface = artifacts.require('LinkTokenInterface')
const LPToken = artifacts.require('LPToken');
const EmergencyPool = artifacts.require('EmergencyPool')
// Constant Addresses
const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";
const policy_token = "0xF29Ca363D07d77c1BD37986791472D7429b3a693";
const degis_token = "0xD51e2fb717A0DDC55aec9990b6F3F8B76D4922D9";
const lptoken = "0xFa0Aa822581fD50d3D8675F52A719919F54f1eBB";


function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = async callback => {
    try {

        console.log('\n -------------Basic Information----------------- \n');
        /********************************* Basic Information ***************************/
        const accounts = await web3.eth.getAccounts();
        const user_account = accounts[0];
        console.log("\n My Account:", user_account);
        console.log("\n Web3 Version:", web3.version)


        // Prepare All contracts
        const pool = await InsurancePool.deployed();
        console.log('\n Insurance Pool Address:', pool.address);

        const policyflow = await PolicyFlow.deployed();
        console.log('\n Policy Flow address:', policyflow.address);

        const usdc = await MockUSD.at(usdcadd_rinkeby);
        console.log("\n USDC Token Address:", usdc.address);


        const degis = await DegisToken.at(degis_token);

        const balance1 = await degis.balanceOf(pool.address);
        console.log("\n Pool Degis Balance:", parseInt(balance1) / 10**18)

        const balance2 = await degis.balanceOf(user_account);
        console.log("\n User Degis Balance before Mint:", parseInt(balance2) / 10**18)


        // Pass Minter Role
        await degis.passMinterRole(pool.address);
        const minter = await degis.minter.call();
        console.log("\n Degis Minter Address:", minter);


        // Mint
        await degis.mint(user_account, 10**18);
        const balance3 = await degis.balanceOf(user_account);
        console.log("\n User Degis Balance after Mint:", parseInt(balance3) / 10**18)

        
        callback(true)
    }
    catch (err) {
        callback(err)
    }
}