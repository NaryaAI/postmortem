require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.4.24",
      },
      {
        version: "0.5.16",
        settings: {},
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: {
        accountsBalance: "100000000000000000000000", // 100000 FUSE
      },
      forking: {
        // url: "https://fuse-mainnet.gateway.pokt.network/v1/lb/6248bca53bd808003a80e650",
        url: "https://explorer-node.fuse.io/",
        blockNumber: 16257352, // 16257293
      }
    }
  }
};
