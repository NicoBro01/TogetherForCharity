const  { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
const { assert, expect } = require("chai")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Lottery Unit Tests", function () {

        let contractFactory, funders, campaignAddress, campaign, provider

        beforeEach(async function () {
            deployer = (await getNamedAccounts()).deployer
            const provider = ethers.getDefaultProvider();
            await deployments.fixture(["ContractFactory"])
            contractFactory = await ethers.getContractAt("TogetherForCharityContractFactory", "0x5FbDB2315678afecb367f032d93F642f64180aa3")
            funders = await ethers.getSigners()
            const transactionResponse = await contractFactory.createCampaignWithTime("Creazione campagna", funders[0], 60, 0, {value: ethers.parseUnits("1", "ether")})
            const transactionReceipt = await transactionResponse.wait(1)
            campaignAddress = transactionReceipt.logs[0].args.campaignAddress
            campaign = await ethers.getContractAt("TogetherForCharityWithTime", campaignAddress)

            
        })

        describe("main", function () {
            it("Create a campaign and send money to beneficiary", async function () {
                
                console.log("Balance at creation: " + await ethers.provider.getBalance(campaignAddress))

                await network.provider.send("evm_increaseTime", [70])
                await network.provider.send("evm_mine", [])

                await campaign.performUpkeep("0x")
                //await expect(campaign.performUpkeep("0x")).to.be.revertedWithCustomError(campaign, "TogetherForCharityWithTime__TransferFailed")

                console.log("Balance after upKeep: " + await ethers.provider.getBalance(campaignAddress))

            })
                
        })
    })


