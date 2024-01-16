/* Script for deploying the contract factory on chains */

const { network, ethers } = require("hardhat");
const { namedAccounts } = require("../hardhat.config");
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function({getNamedAccounts, deployments}) {

  const {deploy, log} = deployments // Getting deploy function and log
  const {deployer} = await getNamedAccounts() // Getting the deployer

  /* Deploying the contract factory */
  const contractFactory = await deploy("TogetherForCharityContractFactory", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  })

  console.log(
    `TogetherForCharity deployed to ${contractFactory.address}`
  )

  /* If we aren't on development chains it will verify the contract */
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(contractFactory.address, [])
  } 

  log("-----------------------------")

}

module.exports.tags = ["all", "ContractFactory"]
