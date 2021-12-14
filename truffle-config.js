const Web3 = require("web3"); // Web3 used for http-provider
const dotenv = require("dotenv");
const HDWalletProvider = require("@truffle/hdwallet-provider");

require("babel-register");
require("babel-polyfill");

// Read the environment settings from .env
const result = dotenv.config();
if (result.error) {
  throw result.error;
}
// console.log(result.parsed);
const mnemonic = process.env.mnemonic;
const infuraKey = process.env.infuraKey;
const phrase_fuji = process.env.phrase;

const fuji_provider = new Web3.providers.HttpProvider(
  `https://api.avax-test.network/ext/bc/C/rpc`
);

module.exports = {
  networks: {
    // development network is for Ganache-Cli (port 7545 when using Ganache-UI)
    development: {
      host: "127.0.0.1", // Localhost (default: none)
      port: 8545, // Standard Ethereum port (default: none)
      network_id: "*", // Any network (default: none)
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          "wss://rinkeby.infura.io/ws/v3/" + infuraKey
        ),
      network_id: 4, // Rinkeby's id
      gas: 5500000, // Ropsten has a lower block limit than mainnet
      confirmations: 2, // # of confs to wait between deployments. (default: 0)
      networkCheckTimeout: 1000000000,
      timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true, // Skip dry run before migrations? (default: false for public nets )
    },
    fuji: {
      provider: () => {
        return new HDWalletProvider({
          mnemonic: {
            phrase: phrase_fuji,
          },
          numberOfAddresses: 1,
          shareNonce: true,
          providerOrUrl: fuji_provider,
        });
      },
      network_id: "*",
      timeoutBlocks: 50000,
      skipDryRun: true,
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.9", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    },
  },
  db: {
    enabled: false,
  },
  // Used for verifying contracts on etherscan
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
  },

  plugins: ["truffle-plugin-verify"],
};
