const { network, ethers } = require("hardhat");
const { namedAccounts } = require("../hardhat.config");
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function({getNamedAccounts, deployments}) {

  const {deploy, log} = deployments
  const {deployer} = await getNamedAccounts()
  const provider = ethers.provider
  let gasLimit = 200000

  const funders = await ethers.getSigners()

  const args = [process.env.SEPOLIA_LINK_CONTRACT, process.env.SEPOLIA_REGISTRAR_ADDRESS, gasLimit]

  const contractFactory = await deploy("TogetherForCharityContractFactory", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  })

  console.log(
    `TogetherForCharity deployed to ${contractFactory.address}`
  )

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(contractFactory.address, args)
  } 

  log("-----------------------------")

}

module.exports.tags = ["all", "ContractFactory"]
