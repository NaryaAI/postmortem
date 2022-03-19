require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.12",
  networks: {
    hardhat: {
      loggingEnabled: true,
      forking: {
        url: "https://rpc.ftm.tools/",
        blockNumber: 33466613
      }
    }
  }
};
