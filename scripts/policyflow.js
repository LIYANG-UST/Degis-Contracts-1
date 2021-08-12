// Contract ABIs
const InsurancePool = artifacts.require('InsurancePool');
const PolicyFlow = artifacts.require('PolicyFlow')
const MockUSD = artifacts.require('MockUSD')
const PolicyToken = artifacts.require('PolicyToken')
const DegisToken = artifacts.require('DegisToken')
const LinkTokenInterface = artifacts.require('LinkTokenInterface')
// Constant Addresses
const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";
const policy_token = "0x2aCE3BdE730B1fF003cDa21aeeA1Db33b0F04ffC";
const degis_token = "0xa5DaDD05F67996EC2428d07f52C9D3852F18c759";

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = async callback => {
    try {
        // Get Account
        const accounts = await web3.eth.getAccounts();
        const account = accounts[0];
        console.log("My Account:", account);
        console.log(web3.version)
        // Prepare All contracts
        const pool = await InsurancePool.deployed();
        console.log('Insurance Pool Address is:', pool.address);

        const policyflow = await PolicyFlow.deployed();
        console.log('Policy Flow address:', policyflow.address);

        const usdc = await MockUSD.at(usdcadd_rinkeby);
        console.log("USDC Address:", usdc.address);

        const policy_nft = await PolicyToken.at(policy_token);
        console.log("Policy NFT Token Address:", policy_nft.address);

        const degis = await DegisToken.at(degis_token);

        const balance = await degis.balanceOf(pool.address);
        console.log("pool degis balance:", parseInt(balance))

        const minter = await degis.passMinterRole(pool.address);
        console.log("Minter Address:", minter.logs[0].args[1]);

        const linkAddress = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709"
        const linkToken = await LinkTokenInterface.at(linkAddress)
        const payment = '2000000000000000000'
        const tx1 = await linkToken.transfer(policyflow.address, payment)
        console.log(tx1.tx)
        // View the link balance in the contract
        let linkBalance = await linkToken.balanceOf(policyflow.address)
        console.log('linkBalance:', web3.utils.fromWei(linkBalance.toString()))

        // Pool basic Info
        const pool_name = await pool.getPoolInfo();
        const pool_bal = await pool.getCurrentStakingBalance();
        const user_bal = await pool.getStakeAmount(account);
        console.log("Pool Name:", pool_name, "pool avac", parseInt(pool_bal) / 10 ** 18, "user bal", parseInt(user_bal) / 10 ** 18);
        // Stake
        console.log('\n -------------depositing 100 each time-----------------');
        let deposit_amount = web3.utils.toWei('100', 'ether');

        const approval_tx = await usdc.approve(pool.address, web3.utils.toBN(deposit_amount), { from: account });
        console.log(approval_tx.tx)

        const approval = await usdc.allowance(account, pool.address);
        console.log("allowance: ", parseInt(approval) / 10 ** 18);

        const stake_tx = await pool.stake(account, web3.utils.toBN(deposit_amount))
        console.log("stake tx:", stake_tx.tx)


        // New Application
        console.log('\n -------------buy a new application-----------------');
        let timestamp = new Date().getTime();
        timestamp = timestamp + 86400000 + 100;
        let premium = web3.utils.toWei('5', 'ether');
        let payoff = web3.utils.toWei('50', 'ether');
        const new_tx = await policyflow.newApplication(account, 0, web3.utils.toBN(premium), web3.utils.toBN(payoff), timestamp);
        console.log('policy id:', new_tx.logs[0].args[0]);

        //Show policy
        console.log('\n -------------show all applications-----------------');
        const policy_amount = await policyflow.getTotalPolicyCount();
        for (let i = 0; i < parseInt(policy_amount); i++) {
            await policyflow.getPolicyIdByCount(i).then(value => {
                console.log("policyId", i + 1, ":", value);
            })
        }
        await sleep(10000)
        // Unstake
        console.log('\n -------------withdraw 20 each time-----------------');
        let withdraw_amount = web3.utils.toWei('20', 'ether');
        const unstake_tx = await pool.unstake(account, web3.utils.toBN(withdraw_amount))
        console.log(unstake_tx.tx)

        // Final check
        // for (let i = 0; i < parseInt(policy_amount); i++) {
        //     policyflow.policyFinalCheck(i).then(value => {
        //         console.log("policyId", i + 1, ":", value);
        //     })
        // }
        let vol = await policyflow.getVolume();
        console.log("volume:", parseInt(vol))
        callback(vol)
    }
    catch (err) {
        callback(err)
    }
}