require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter")
require("solidity-coverage")
require("hardhat-deploy")
require("dotenv").config()

const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY
const PRIVATE_KEY = process.env.PRIVATE_KEY
const ETHERSCAN_API_KEY=process.env.ETHERSCAN_API_KEY
const POLYGONSCAN_API_KEY=process.env.POLYGONSCAN_API_KEY
const SEPOLIA_RPC_URL=process.env.SEPOLIA_RPC_URL
const MUMBAI_RPC_URL=process.env.MUMBAI_RPC_URL
const POLYGON_RPC_URL=process.env.POLYGON_RPC_URL

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat:{
      chainId: 31337,
      accounts: {
        count: 3,
        accountsBalance: "10000000000000000000000", 
      }
    },
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
      blockConfirmations: 6,
    }, 
    mumbai: {
      url: MUMBAI_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 80001,
      blockConfirmations: 6
    },
    polygon: {
      url: POLYGON_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 137,
      blockConfirmations: 6
    }
  },
  solidity: "0.8.20",
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    coinmarketcap: COINMARKETCAP_API_KEY,
    token: "ETH"
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    funders: {
      first: 0,
      second: 1
    }
  },
  etherscan: {
    apiKey: {
        sepolia: ETHERSCAN_API_KEY,
        polygonMumbai: POLYGONSCAN_API_KEY,
        polyon: POLYGONSCAN_API_KEY
    },
  },
};
