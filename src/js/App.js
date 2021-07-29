

const usdcadd_rinkeby = "0x6e95Fc19611cebD936B22Fd1A15D53d98bb31dAF";

//const Web3 = require('web3');
App = {
    web3Provider: null,
    contracts: {},
    account: null,

    //初始化
    init: async function () {
        App.initweb3();

        web3.eth.getAccounts(function (error, accounts) {
            if (error) {
                console.log(error);
            }

            App.account = accounts[0];
            console.log("my account:", App.account)
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
    initContract: function () {
        $.getJSON("DegisToken.json", function (data) {
            var DegisTokenArtifact = data;
            App.contracts.DegisToken = TruffleContract(DegisTokenArtifact);
            App.contracts.DegisToken.setProvider(App.web3Provider);
        });
        $.getJSON("MockUSD.json", function (data) {
            var usdcArtifact = data;
            App.contracts.USDC = TruffleContract(usdcArtifact);
            App.contracts.USDC.setProvider(App.web3Provider);
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

        //调用事件
        return App.bindEvents();
    },

    bindEvents: function () {
        $(document).on('click', '.btn-mint', App.mint);
        $(document).on('click', '.btn-getpoolinfo', App.getPoolInfo);
        $(document).on('click', '.btn-stake', App.deposit);
        $(document).on('click', '.btn-buy', App.newApplication);
        $(document).on('click', '.btn-rand', App.getRandomness);
        $(document).on('click', '.btn-LPInfo', App.showLPInfo);
        $(document).on('click', '.btn-unstake', App.withdraw);
    },
    //合约的mint方法
    mint: function () {
        //deployed得到合约的实例，通过then的方式回调拿到实例
        var DegisInstance;
        console.log("test....");
        App.contracts.DegisToken.deployed().then(function (instance) {
            DegisInstance = instance;
            let mintaddress = document.getElementById("minter").value;
            let mint_num = document.getElementById("mint_number").value;
            mint_num = web3.utils.toWei(mint_num, 'ether');
            console.log(typeof (mintaddress), typeof (mint_num));
            return DegisInstance.mint(mintaddress, web3.utils.toBN(mint_num), { from: App.account });
        }).catch(function (err) { //get方法执行失败打印错误
            console.log(err.message);
        });
    },

    getPoolInfo: function () {
        var PoolInstance;
        console.log('get pool info...');

        App.contracts.InsurancePool.deployed().then(function (instance) {
            PoolInstance = instance;
            PoolInstance.getPoolInfo({ from: App.account }).then(value => console.log("pool name:", value));
            PoolInstance.getAvailableCapacity({ from: App.account }).then(value => console.log("available capacity", parseInt(value) / 10 ** 18));
            PoolInstance.getTotalLocked({ from: App.account }).then(value => console.log("total locked amount:", parseInt(value) / 10 ** 18));
        }).catch(function (err) { //get方法执行失败打印错误
            console.log(err.message);
        });
    },

    showLPInfo: function () {
        App.contracts.InsurancePool.deployed().then(function (instance) {
            PoolInstance = instance;
            PoolInstance.getStakeAmount(App.account, { from: App.account }).then(value => {
                // console.log(value)
                console.log("your stake amount:", parseInt(value) / 10 ** 18)
                var obj = document.getElementById("lpinfo-show");
                //alert(obj.innerText);
                obj.innerText = ("stake amount:  " + parseInt(value) / 10 ** 18);
            });
            PoolInstance.getUnlockedfor(App.account, { from: App.account }).then(value => {
                console.log("your unlocked amount:", parseInt(value) / 10 ** 18);
                var obj = document.getElementById("lpinfo-show");
                //alert(obj.innerText);
                obj.innerText += ("\n unlocked amount:  " + parseInt(value) / 10 ** 18);
            }
            );

        });
    },

    getRandomness: function () {
        var CLInstance;
        console.log('get random number...');
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


    newApplication: function () {
        console.log('buy new policy');

        //let PolicyFlowInstance = await App.contracts.PolicyFlow.deployed();
        let premium = web3.utils.toWei(document.getElementById("premium").value, 'ether');
        let payoff = web3.utils.toWei(document.getElementById("payoff").value, 'ether');
        var timestamp = new Date().getTime();
        console.log("departure time:", timestamp);
        timestamp = timestamp + 86400000 + 100;

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
                    console.log(value)
                    // const sstringname = web3.utils.toAscii(value);
                    // console.log(sstringname);
                })
        })
    },

    deposit: function () {
        var PoolInstance;
        var USDCInstance;

        console.log('depositing...');

        App.contracts.USDC.at(usdcadd_rinkeby).then(function (instance) {
            USDCInstance = instance;
            //return USDCInstance.approve(PoolInstance.address, web3.utils.toBN(f_amount), { from: App.account });
        }).catch(function (err) { //get方法执行失败打印错误
            console.log(err.message);
        }).then(
            App.contracts.InsurancePool.deployed().then(function (instance) {
                PoolInstance = instance;
                let deposit_amount = document.getElementById('stake_number').value;
                console.log("deposit amount in token:", deposit_amount)
                f_amount = web3.utils.toWei(deposit_amount, 'ether');
                console.log("deposit amount in wei:", f_amount)

                return PoolInstance.stake(App.account, web3.utils.toBN(f_amount), { from: App.account });
            }).catch(function (err) { //get方法执行失败打印错误
                console.log(err.message);
            }));

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
        var USDCInstance;

        console.log('withdrawing...');

        App.contracts.USDC.at(usdcadd_rinkeby).then(function (instance) {
            USDCInstance = instance;
            //return USDCInstance.approve(PoolInstance.address, web3.utils.toBN(f_amount), { from: App.account });
        }).catch(function (err) { //get方法执行失败打印错误
            console.log(err.message);
        }).then(
            App.contracts.InsurancePool.deployed().then(function (instance) {
                PoolInstance = instance;
                let deposit_amount = document.getElementById('stake_number').value;
                console.log("deposit amount in token:", deposit_amount)
                f_amount = web3.utils.toWei(deposit_amount, 'ether');
                console.log("deposit amount in wei:", f_amount)

                return PoolInstance.unstake(App.account, web3.utils.toBN(f_amount), { from: App.account });
            }).catch(function (err) { //get方法执行失败打印错误
                console.log(err.message);
            }));
    }


};

//加载应用
$(function () {
    $(window).on("load", function () {
        App.init();
    });
});
