App = {

    web3Provider: null,
    contracts: {},

    //初始化
    init: function () {
        return App.initweb3();
    },

    //初始化web3
    initweb3: function () {
        if (window.ethereum) {
            App.web3Provider = window.ethereum;
            try {
                await window.ethereum.enable();
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

        web3 = new Web3(App.web3Provider);

        return App.initContract();
    },

    //初始化合约
    initContract: function () {
        $.getJSON("DegisToken.json", function (data) {
            var DegisTokenArtifact = data;

            App.contracts.DegisToken = TruffleContract(DegisTokenArtifact);
            App.contracts.DegisToken.setProvider(App.web3Provider);
        });

        //调用事件
        return App.bindEvents();
    },

    //合约的get方法
    mint: function () {
        //deployed得到合约的实例，通过then的方式回调拿到实例
        var DegisInstance;

        App.contracts.DegisToken.deployed().then(function (instance) {
            DegisInstance = instance;
            return DegisInstance.getAdopters.call();
        }).then(function (result) { //异步执行，get方法执行完后回调执行then方法，result为get方法的返回值
            $("#info").html(`执行结果为` + result[0]);
        }).catch(function (err) { //get方法执行失败打印错误
            console.log(err.message);
        })
    },

    bindEvents: function () {
        $(document).on('click', '#mint', App.mint);
    },

}

//加载应用
$(function () {
    $(window).load(function () {
        App.init();
    });
});

