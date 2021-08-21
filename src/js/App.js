const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";
// const pool_address = '0xDcB6B0D63b4A6011dF2239A070fdcf65c67f366A';
const policy_token_address = "0x2aCE3BdE730B1fF003cDa21aeeA1Db33b0F04ffC";
const degis_token = "0xa5DaDD05F67996EC2428d07f52C9D3852F18c759";
const lp_token = "0xFa0Aa822581fD50d3D8675F52A719919F54f1eBB";

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
//const Web3 = require('web3');
App = {
    web3Provider: null,
    contracts: {},
    account: null,
    policyAddress: null,
    pool_address: null,
    isInit: false,

    //初始化
    init: async function () {
        await App.initweb3();

        web3.eth.getAccounts(function (error, accounts) {
            if (error) {
                console.log(error);
            }

            App.account = accounts[0];
            console.log("my account:", App.account)

            var acc = document.getElementById("account");
            acctext = "Account: \xa0 \xa0";
            acctext += App.account;
            acc.innerText = acctext;

            var bal = document.getElementById("balance");
            web3.eth.getBalance(App.account).then(value => {
                baltext = "Balance: \xa0 \xa0";
                baltext += value / 10 ** 18;
                baltext += "\xa0 ETH";
                bal.innerText = baltext;
            });

        });

    },

    //初始化web3
    initweb3: async function () {
        console.log("init web3....")
        if (window.ethereum) {
            App.web3Provider = window.ethereum;
            try {
                await window.ethereum.request
                    ({ method: 'eth_requestAccounts' });
            }
            catch (error) {
                console.error('user denied account access');
            }
        }
        else if (window.web3) {
            App.web3Provider = window.web3.currentProvider;
        }
        else {
            App.web3Provider = new Web3.providers.HttpProvider('http://localhost:7545');

        }
        console.log("init web3 finished...")
        web3 = new Web3(App.web3Provider);
        console.log('web3 version', web3.version)
        const netId = await web3.eth.net.getId()
        console.log("network id:", netId);
        return App.initContract();
    },



    //初始化合约
    initContract: async function () {
        $.getJSON("DegisToken.json", function (data) {
            var DegisTokenArtifact = data;
            App.contracts.DegisToken = TruffleContract(DegisTokenArtifact);
            App.contracts.DegisToken.setProvider(App.web3Provider);
            console.log('init degis token \n')
        });
        $.getJSON("MockUSD.json", function (data) {
            var usdcArtifact = data;
            App.contracts.USDC = TruffleContract(usdcArtifact);
            App.contracts.USDC.setProvider(App.web3Provider);
        });
        $.getJSON("PolicyToken.json", function (data) {
            var policyTokenArtifact = data;
            App.contracts.PolicyToken = TruffleContract(policyTokenArtifact);
            App.contracts.PolicyToken.setProvider(App.web3Provider);
        });
        $.getJSON("LPToken.json", function (data) {
            var LPTokenArtifact = data;
            App.contracts.LPToken = TruffleContract(LPTokenArtifact);
            App.contracts.LPToken.setProvider(App.web3Provider);
        });
        $.getJSON("InsurancePool.json", function (data) {
            var InsurancePoolArtifact = data;
            App.contracts.InsurancePool = TruffleContract(InsurancePoolArtifact);
            App.contracts.InsurancePool.setProvider(App.web3Provider);
            console.log('init insurance pool')
        });
        $.getJSON("PolicyFlow.json", function (data) {
            var PolicyFlowArtifact = data;
            App.contracts.PolicyFlow = TruffleContract(PolicyFlowArtifact);
            App.contracts.PolicyFlow.setProvider(App.web3Provider);
            console.log('init policy flow')
        });
        $.getJSON("GetFlightData.json", function (data) {
            var GetFlightDataArtifact = data;
            App.contracts.GetFlightData = TruffleContract(GetFlightDataArtifact);
            App.contracts.GetFlightData.setProvider(App.web3Provider);
            console.log('init get flight data')
        });
        $.getJSON("LinkTokenInterface.json", function (data) {
            var LinkTokenArtifact = data;
            App.contracts.LinkTokenInterface = TruffleContract(LinkTokenArtifact);
            App.contracts.LinkTokenInterface.setProvider(App.web3Provider);
            console.log('init get flight data')
        });

        //调用事件
        return App.bindEvents();
    },

    bindEvents: function () {
        $(document).on('click', '.btn-mint', App.mint);
        $(document).on('click', '.btn-mintnft', App.mintNFT);
        $(document).on('click', '.btn-getpoolinfo', App.getPoolInfo);
        $(document).on('click', '.btn-stake', App.deposit);
        $(document).on('click', '.btn-buy', App.newApplication);
        $(document).on('click', '.btn-rand', App.getRandomness);
        $(document).on('click', '.btn-LPInfo', App.showLPInfo);
        $(document).on('click', '.btn-unstake', App.withdraw);
        $(document).on('click', '.btn-allowance', App.checkAllowance);
        $(document).on('click', '.btn-userpolicy', App.showUserPolicy);
        $(document).on('click', '.btn-totalpolicy', App.showTotalPolicy);
        $(document).on('click', '.btn-updatepolicyflow', App.updateFlow);
        $(document).on('click', '.btn-updatepooladdress', App.updatePoolAddress);
        $(document).on('click', '.btn-oracle', App.requestOracle);
        $(document).on('click', '.btn-changeCollateralFactor', App.changeFactor);
        $(document).on('click', '.btn-calc', App.calculate);
    },

    updatePoolAddress: async function () {
        console.log("update pool -------------------------------")
        const pool = await App.contracts.InsurancePool.deployed();
        App.pool_address = pool.address;
        console.log('Updating pool address:', App.pool_address)
        var obj = document.querySelector('#pooladdress');
        obj.innerText = "Pool Address: \xa0 \xa0" + App.pool_address;


    },

    //合约的mint方法
    mint: async function () {
        //deployed得到合约的实例，通过then的方式回调拿到实例

        console.log("\n-------------Pass the Minter Role---------------\n");

        const dt = await App.contracts.DegisToken.at(degis_token);
        console.log("\n Degis token address: ", dt.address)

        const lptoken = await App.contracts.DegisToken.at(lp_token);
        console.log("\n LP token address: ", lptoken.address)

        let mintaddress = document.getElementById("minter").value;

        if (mintaddress == "") {
            const minter_d = await dt.passMinterRole(App.pool_address, { from: App.account });
            console.log("\n Degis Minter Address:", minter_d.logs[0].args[1]);
            const minter_l = await lptoken.passMinterRole(App.pool_address, { from: App.account });
            console.log("\n Degis Minter Address:", minter_l.logs[0].args[1]);
        }
        else {
            const minter_d = await dt.passMinterRole(mintaddress, { from: App.account });
            console.log("\n Degis Minter Address:", minter_d.logs[0].args[1]);
            const minter_l = await lptoken.passMinterRole(mintaddress, { from: App.account });
            console.log("\n Degis Minter Address:", minter_l.logs[0].args[1]);
        }


        // let mint_num = document.getElementById("mint_number").value;
        // mint_num = web3.utils.toWei(mint_num, 'ether');
        // const usdc = await App.contracts.USDC.at(usdcadd_rinkeby);
        // await dt.mint(mintaddress, web3.utils.toBN(mint_num), { from: App.account });

    },

    mintNFT: async function () {
        //deployed得到合约的实例，通过then的方式回调拿到实例

        console.log("\n---------------Mint NFT Policy Token-----------------\n");
        const policytoken = await App.contracts.PolicyToken.at(policy_token_address)
        const tx = await policytoken.mintPolicyToken(App.account, { from: App.account });
        console.log(tx.tx)
    },

    checkAllowance: function () {
        var USDCInstance;
        console.log('\n -----------------Check Allowance----------------');

        App.contracts.USDC.at(usdcadd_rinkeby).then(function (instance) {
            USDCInstance = instance;
            console.log("Usdc address:", USDCInstance.address)
            return USDCInstance.allowance(App.account, App.pool_address, { from: App.account });
        }).then(value => {
            console.log("ERC20 Allowance: ", (value / 10 ** 18).toString())
        }
        ).catch(function (err) {
            console.log(err.message)
        });
    },

    getPoolInfo: async function () {

        console.log('\n ---------------Get pool info-----------------\n');

        const pool = await App.contracts.InsurancePool.deployed()

        console.log("Pool address:", pool.address)
        await pool.getPoolInfo({ from: App.account })
            .then(value => console.log("Pool name:", value));

        await pool.getCurrentStakingBalance({ from: App.account })
            .then(value => console.log("Current Staking Balance in the pool:", parseInt(value) / 10 ** 18));

        await pool.getAvailableCapacity({ from: App.account })
            .then(value => console.log("Available capacity in the pool:", parseInt(value) / 10 ** 18));

        await pool.getTotalLocked({ from: App.account })
            .then(value => console.log("Total locked amount in the pool:", parseInt(value) / 10 ** 18));

        await pool.getPoolUnlocked({ from: App.account })
            .then(value => console.log("Total unlocked amount in the pool:", parseInt(value) / 10 ** 18));

        // await pool.getLockedRatio({ from: App.account })
        //     .then(value => console.log("Locked Ratio:", parseInt(value)));

        // await pool.getCollateralFactor({ from: App.account })
        //     .then(value => console.log("Collateral Factor:", parseInt(value)));

        await pool.getPRBRatio({ from: App.account })
            .then(value => console.log("PRB Ratio:", parseInt(value) / 10 ** 18));

        const usdc = await App.contracts.USDC.at(usdcadd_rinkeby)
        await usdc.balanceOf(App.pool_address, { from: App.account })
            .then(value => console.log("Total USDC balance in the pool:", parseInt(value) / 10 ** 18));

        await usdc.allowance(App.account, App.pool_address, { from: App.account })
            .then(value => console.log("USDC allowance of the pool:", parseInt(value) / 10 ** 18));

        const policyflow = await App.contracts.PolicyFlow.deployed()
        await policyflow.getResponse({ from: App.account })
            .then(value => console.log("response value", parseInt(value)));

        // await policyflow.setDelayThreshold(240, { from: App.account });
        // const de_t = await policyflow.getDelayThreshold();
        // console.log("delay threshold:", de_t)

        const reward_collected = await pool.getRewardCollected();
        console.log("reward collected:", parseInt(reward_collected) / 10 ** 18)

        const pf_add = await pool.policyFlow.call()
        console.log("policy flow in the pool:", pf_add)

    },

    changeFactor: async function () {
        const pool = await App.contracts.InsurancePool.at(App.pool_address);
        const tx = await pool.calcFactor(5, 10, { from: App.account });
        console.log(tx);
        const cf = await pool.getCollateralFactor();
        console.log(cf / 2 * 112)
    },

    calculate: async function () {
        const pool = await App.contracts.InsurancePool.at(App.pool_address);
        let n = document.getElementById("numerator").value;
        let d = document.getElementById("denominator").value;
        const tx = await pool.doDiv(parseInt(n), parseInt(d), { from: App.account });
        console.log("do div:", parseInt(tx) / 10 ** 18);

        const tx2 = await pool.doMul(web3.utils.toBN(n * 10 ** 18), web3.utils.toBN(d * 10 ** 18), { from: App.account });
        console.log("do mul:", parseInt(tx2) / 10 ** 18);
    },

    updateFlow: async function () {
        const policyflow = await App.contracts.PolicyFlow.deployed()
        App.policyAddress = policyflow.address;
        console.log("new policy address:", policyflow.address);

        const pool = await App.contracts.InsurancePool.deployed();
        const tx = await pool.setPolicyFlow(policyflow.address, { from: App.account });
        console.log(tx.tx);
        const pf_add = await pool.policyFlow.call()
        console.log("Policy flow in the pool:", pf_add)

        const policytoken = await App.contracts.PolicyToken.at(policy_token_address)
        policytoken.updatePolicyFlow(App.policyAddress, { from: App.account });

    },

    showLPInfo: async function () {
        console.log('\n --------------Show LP info----------------');
        const ip = await App.contracts.InsurancePool.deployed()
        console.log(ip.address)
        const stakeamount = await ip.getStakeAmount(App.account, { from: App.account })
        console.log("your stake amount:", parseInt(stakeamount) / 10 ** 18)
        let obj = document.getElementById("lpinfo-show");
        obj.innerText = ("stake amount:  " + parseInt(stakeamount) / 10 ** 18);


        const unlocked = await ip.getUnlockedfor(App.account, { from: App.account })
        console.log("your unlocked amount:", parseInt(unlocked) / 10 ** 18);
        obj.innerText += ("\n unlocked amount:  " + parseInt(unlocked) / 10 ** 18);


        await ip.getLockedfor(App.account, { from: App.account }).then(value => {
            console.log("your locked amount:", parseInt(value) / 10 ** 18);
        })

        const pendingDegis = await ip.pendingDegis(App.account)
        console.log("pending degis:", parseInt(pendingDegis) / 10 ** 18)
        obj.innerText += ("\n pending degis:  " + parseInt(pendingDegis) / 10 ** 18);

        const pendingPremium = await ip.pendingPremium(App.account)
        console.log("pending premium:", parseInt(pendingPremium) / 10 ** 18)
        obj.innerText += ("\n pending premium:  " + parseInt(pendingPremium) / 10 ** 18);


    },

    getRandomness: function () {
        var CLInstance;
        console.log('\n ----------get random number------------');
        App.contracts.GetFlightData.deployed().then(function (instance) {
            CLInstance = instance;
            return CLInstance.getRandomNumber({ from: App.account });

        }).then(value => {
            // console.log("value tyte:", typeof (value))
            ret = value.logs[0].args[0]; //返回值是交易信息，需要这样获取值
            console.log(ret);
            console.log(web3.utils.toAscii(ret))
            // var r_value = web3.utils.hexToAscii(value);
            // console.log(r_value);
            CLInstance.getResult({ from: App.account }).then(p_value => {
                console.log(typeof (p_value))
                console.log(parseInt(p_value));
                console.log(web3.utils.toBN(p_value));
            });

        });
    },

    timestampToTime: function (timestamp) {
        let date = new Date(timestamp);
        Y = date.getFullYear() + '-';
        M = (date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : date.getMonth() + 1) + '-';
        D = (date.getDate() < 10 ? '0' + date.getDate() : date.getDate()) + ' ',
            h = (date.getHours() < 10 ? '0' + date.getHours() : date.getHours()) + ':';
        m = (date.getMinutes() < 10 ? '0' + date.getMinutes() : date.getMinutes()) + ':';
        s = (date.getSeconds() < 10 ? '0' + date.getSeconds() : date.getSeconds());
        return Y + M + D + h + m + s;
    },

    newApplication: async function () {
        console.log('\n ------------Buy new policy----------------');

        //let PolicyFlowInstance = await App.contracts.PolicyFlow.deployed();
        let premium = web3.utils.toWei(document.getElementById("premium").value, 'ether');
        let payoff = web3.utils.toWei(document.getElementById("payoff").value, 'ether');
        var timestamp = new Date().getTime();

        timestamp = timestamp + 86400000 + 100;
        console.log("departure timestamp:", timestamp);
        console.log("departure time:", App.timestampToTime(timestamp));

        const usdc = await App.contracts.USDC.at(usdcadd_rinkeby)

        await usdc.approve(App.pool_address, web3.utils.toBN(premium), { from: App.account });

        App.contracts.PolicyFlow.deployed().then(function (instance) {
            PolicyFlowInstance = instance;
            // console.log("parameters:", App.account, parseInt(premium), parseInt(payoff), timestamp)

            PolicyFlowInstance.newApplication(App.account,
                0,
                web3.utils.toBN(premium),
                web3.utils.toBN(payoff),
                timestamp, { from: App.account })
                .catch(err => console.warn(err))
                .then(value => {
                    // var str = web3.utils.toAscii("0x657468657265756d000000000000000000000000000000000000000000000000");
                    // console.log(str);
                    console.log(value);
                    console.log("policy Id:", value.logs[0].args[0])
                    // const sstringname = web3.utils.toAscii(value);
                    // console.log(sstringname);
                })
        })
    },

    showTotalPolicy: async function () {
        console.log('\n ------------Showing total policies-------------');
        const pf = await App.contracts.PolicyFlow.deployed()

        const total_policy = await pf.getTotalPolicyCount()
        console.log("Total policy amount in the pool:", parseInt(total_policy));
        for (let i = 0; i < parseInt(total_policy); i++) {
            await pf.getPolicyIdByCount(i, { from: App.account }).then(value => {
                console.log("policyId", i, ":", value);
            })
            await pf.getPolicyInfoByCount(i, { from: App.account }).then(value => {
                console.log(value)
            })
        }



    },

    deposit: async function () {

        console.log('\n -------------depositing-----------------');


        deposit_amount = document.getElementById('stake_number').value;
        console.log("deposit amount in token:", deposit_amount)
        f_amount = web3.utils.toWei(deposit_amount, 'ether');
        console.log("deposit amount in wei:", f_amount)

        const usdc = await App.contracts.USDC.at(usdcadd_rinkeby)

        await usdc.approve(App.pool_address, web3.utils.toBN(f_amount), { from: App.account });

        // .catch(function (err) { //get方法执行失败打印错误
        //     console.log(err.message);
        // }).then(

        const pool = await App.contracts.InsurancePool.deployed();

        await pool.stake(App.account, web3.utils.toBN(f_amount), { from: App.account });


        //var USDCInstance = new web3.eth.Contract(App.contracts.USDC, usdcadd_rinkeby);

        // App.contracts.InsurancePool.deployed().then(function (instance) {
        //     PoolInstance = instance;
        //     let deposit_amount = document.getElementById('stake_number').value;
        //     console.log("deposit amount in token:", deposit_amount)
        //     f_amount = web3.utils.toWei(deposit_amount, 'ether');
        //     console.log("deposit amount in wei:", f_amount)
        //     console.log("pool address", PoolInstance.address)

        //     // USDCInstance.approve(PoolInstance.address, web3.utils.toBN(f_amount)).send({ from: App.account }, function (error, transactionHash) {
        //     //     console.log("trnsanctionHash", transactionHash);
        //     //     console.log(error.message);
        //     // });

        //     PoolInstance.stake(App.account, web3.utils.toBN(f_amount), { from: App.account });
        //     console.log("stake")
        // }).catch(function (err) { //get方法执行失败打印错误
        //     console.log(err.message);
        // });
    },

    withdraw: function () {
        var PoolInstance;

        console.log('\n -------------withdrawing-------------------');

        deposit_amount = document.getElementById('stake_number').value;
        console.log("withdraw amount in token:", deposit_amount)
        f_amount = web3.utils.toWei(deposit_amount, 'ether');
        console.log("withdraw amount in wei:", f_amount)

        App.contracts.InsurancePool.deployed().then(function (instance) {
            PoolInstance = instance;

            return PoolInstance.unstake(App.account, web3.utils.toBN(f_amount), { from: App.account });
        }).catch(function (err) { //get方法执行失败打印错误
            console.log(err.message);
        })

    },


    showUserPolicy: function () {
        console.log('\n----------------showing user policy--------------\n');
        var PolicyFlowInstance;

        App.contracts.PolicyFlow.deployed().then(function (instance) {
            PolicyFlowInstance = instance;
            console.log("policy address:", PolicyFlowInstance.address);
            PolicyFlowInstance.getUserPolicyCount(App.account, { from: App.account }).then(value => {
                console.log("your policy amount:", value.toString())
                var obj = document.getElementById("userpolicy-show");
                //alert(obj.innerText);
                obj.innerText = (" your policy amount:  " + parseInt(value));
            });
        }).catch(function (err) {
            console.log(err.message);
        })

        App.contracts.PolicyFlow.deployed().then(function (instance) {
            instance.viewPolicy(App.account, { from: App.account }).then(value => {
                console.log(value);
            })
        }).catch(function (err) {
            console.log(err.message);
        })

        App.contracts.PolicyFlow.deployed().then(function (instance) {
            instance.bytesToUint("0x3232322e39350000000000000000000000000000000000000000000000000000", { from: App.account }).then(value => {
                console.log(parseInt(value));
            })
        })

    },

    requestOracle: async function () {
        console.log("\n------------------Request Oracle-----------------------\n")
        flight_number = document.getElementById('flightNumber').value;
        console.log("flight number is:", flight_number);

        policy_order = document.getElementById('policyOrder').value;
        console.log("policy order is:", policy_order);

        date = document.getElementById('date').value;
        console.log("date is:", date);

        const ps = await App.contracts.PolicyFlow.deployed()
        console.log("policy flow address:", ps.address)

        // const linkAddress = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709"
        const linkAddress = await ps.getChainlinkToken()
        console.log("link address:", linkAddress)
        const linkToken = await App.contracts.LinkTokenInterface.at(linkAddress)

        const payment = '1000000000000000000'
        const tx1 = await linkToken.transfer(ps.address, payment, { from: App.account })
        console.log(tx1.tx)

        // const req = await ps.calculateFlightStatus(parseInt(policy_order),
        //     flight_number,
        //     date,
        //     "data.0.depart_delay",
        //     true, { from: App.account });
        const req = await ps.calculateFlightStatus(policy_order,
            flight_number,
            date,
            "data.0.depart_delay",
            true, { from: App.account });
        console.log(req)

        var flightStatus = await ps.getResponse()

        console.log('flightStatus:', flightStatus)


        await sleep(60000)
        flightStatus = await ps.getResponse()

        console.log('flightStatus:', flightStatus)
    }





};

//加载应用
$(function () {
    $(document).on('click', '.btn-init', async function () {
        if (App.isInit == false) {
            await App.init();
        }
    })
    $(window).on("load", async function () {
        await App.init();
        App.isInit = true;
    });
});
