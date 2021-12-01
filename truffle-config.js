const HDWalletProvider = require("@truffle/hdwallet-provider");
const dotenv = require('dotenv');
dotenv.config();

//var HDWalletProvider = require("truffle-hdwallet-provider");
//var mnemonic = "drastic guard shy second sadness clinic gallery dose health type ten resource";

module.exports = {
  networks: {
    development: {
      host: process.env.HOST,
      port: process.env.PORT,
      network_id: "*" // Match any network id
    },
    /*
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*',
      gas: 9999999
    }
    */
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
    timeout: 20000
  },
  compilers: {
    /*
    solc: {
      version: "^0.4.24"
    }
    */
  }
};