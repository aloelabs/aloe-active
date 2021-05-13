import fs from 'fs';
import path from 'path';

require('dotenv-safe').config();

require('@nomiclabs/hardhat-truffle5');

require('@nomiclabs/hardhat-etherscan');

const mochaConfig = {
  timeout: 180000,
  grep: '@hardhat',
};

const compilerSettings = {
  optimizer: {
    enabled: true,
    runs: 800,
  },
  metadata: { bytecodeHash: 'none' },
};

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.PROVIDER_ALCHEMY_KEY}`,
        blockNumber: 12519847,
      }
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.PROVIDER_ALCHEMY_KEY}`,
      gasPrice: 42000000000,
      gasMultiplier: 1.15,
      timeout: 720000,
    },
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${process.env.PROVIDER_ALCHEMY_KEY}`,
      timeout: 720000,
      accounts: [process.env.KOVAN_DEPLOYER],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: compilerSettings,
      },
    ],
  },
  paths: {
    sources: './contracts',
    tests: './tests',
    artifacts: './build',
  },
  mocha: mochaConfig,
};
