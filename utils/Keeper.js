const { getNamedAccounts, ethers } = require("hardhat")
const { verify } = require("./verify")

/* Getting contracts ABIs */
const FACTORY_ABI = require("../ABI/FactoryABI.json");
const TIME_ABI = require("../ABI/TimeCampaignABI.json")
const TARGET_ABI = require("../ABI/TargetCampaignABI.json");
const STEPS_ABI = require("../ABI/StepsCampaignABI.json")

/* Getting RPC URL for connecting to the blockchain network */
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;

/* Getting the provider */
provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL)

/* Getting the address of the deployed contract factory */
const FACTORY_CONTRACT_ADDRESS = process.env.FACTORY_CONTRACT_ADDRESS; 

let campaigns = []
let signer

/* Getting the signer */
async function getSigner() {
    const signers = await ethers.getSigners()
    signer = signers[0]
}
getSigner()

/* Getting the contract factory contract */
contractFactory = new ethers.Contract(FACTORY_CONTRACT_ADDRESS, FACTORY_ABI, provider)

/* Listening to "CampaignCreated" event emitted by the contract factory to get the created campaign contract and to verify it */
contractFactory.on("CampaignCreated", (campaignID, campaignAddress, creator, beneficiary, campaignType) => {

    try {

        console.log("Campaign created! Address: " + campaignAddress)

        /* Checking what type of campaign the contract factory created to call verifyCampaignContract with the right contract ABI
           setTimeout is necessary because block explorers need time to update everything. Without it, incompatibility errors may occur */

        if (campaignType == 0) {

            const newCampaign = new ethers.Contract(campaignAddress, TARGET_ABI, signer)
            campaigns.push(newCampaign)
            setTimeout(() => verifyCampaignContract(newCampaign, campaignAddress, campaignType), 30000)
            
        } else if (campaignType == 1) {

            const newCampaign = new ethers.Contract(campaignAddress, TIME_ABI, signer)
            campaigns.push(newCampaign)
            setTimeout(() => verifyCampaignContract(newCampaign, campaignAddress, campaignType), 30000)
            
        } else if (campaignType == 2) {

            const newCampaign = new ethers.Contract(campaignAddress, STEPS_ABI, signer)
            campaigns.push(newCampaign)
            setTimeout(() => verifyCampaignContract(newCampaign, campaignAddress, campaignType), 30000)
        }

        printCampaigns()

    } catch (error) {
        console.error(`Error handling CampaignCreated event: ${error.message}`);
    }

})

/* Function to verify new campaign contracts created */
async function verifyCampaignContract(newCampaign, campaignAddress, campaignType) {

    console.log(`Verifying Campaign Contract ${campaignAddress}...`)

    /* Getting constructor parameters */
    const campaignID = await newCampaign.getCampaignID()
    const description = await newCampaign.getDescription()
    const creator = await newCampaign.getCreator()
    const beneficiary = await newCampaign.getBeneficiary()
    const minimumAmount = await newCampaign.getMinimumDonation()

    let args

    /* Getting right parameters based on wich type of campaign was created */
    if (campaignType == 0) {

        const targetAmount = await newCampaign.getTargetAmount()
        args = [campaignID, description, creator, beneficiary, targetAmount, minimumAmount]
        
    } else if (campaignType == 1) {

        const totalTime = await newCampaign.getCampaignDurationSeconds()
        args = [campaignID, description, creator, beneficiary, totalTime, minimumAmount]
        
    } else if (campaignType == 2) {
        
        const targetAmount = await newCampaign.getTargetAmount()
        const steps = await newCampaign.getTotalSteps()
        const stepTimeInterval = await newCampaign.getStepDurationInSeconds()
        args = [campaignID, description, creator, beneficiary, minimumAmount, targetAmount, steps, stepTimeInterval]
    }

    try {

        /* Verifying campaign contract */
        await verify(campaignAddress, args)

    } catch (error) {

        console.error(`Error during verifying contract ${campaignAddress}: ${error.message}`);

    }

}

/* Listening to all new blocks mined in the blockchain to call checkUpkeep for each created campaign */
provider.on('block', async (blockNumber) => {

    if(campaigns.length > 0) {

        for (let i = campaigns.length - 1; i >= 0; i--) {

            const campaignAddress = await campaigns[i].getCampaignAddress()
            const closed = await campaigns[i].getCampaignState()
            const type = await campaigns[i].getCampaignType()

            let currentStep
            let totalSteps
            
            if (type == "Steps") {
                currentStep = await campaigns[i].getCurrentStep()
                totalSteps = await campaigns[i].getTotalSteps()
            }

            /* If campaign is closed it will be removed from the array */
            if (closed == 1) {

                if (type == "Steps") {
                    /* If it's a campaign with steps and the last step was delivered, it remove the campaign from the array */
                    if (Number(currentStep) == Number(totalSteps) - 1) {

                        console.log("Campaign " + campaignAddress + " delivered");
                        campaigns.splice(i, 1);
                        await printCampaigns()
                        break;

                    }
                } else {

                    console.log("Campaign " + campaignAddress + " delivered");
                    campaigns.splice(i, 1);
                    await printCampaigns()
                    break;

                }
            }

            try {

                const upkeepNeeded = await campaigns[i].checkUpkeep()
    
                /* If upkeep is needed for this campaign, it will call performUpkeep and will remove the campaign from the array,
                   if and only if the campaign isn't a campaign with steps or is a campaign with steps and last step is delivered */
                if (upkeepNeeded) {

                    console.log("Upkeep Needed for " + campaignAddress);
                    await performUpkeepOnCampaign(i)

                    if (type == "Steps") {

                        if (Number(currentStep) == Number(totalSteps) - 1) {

                            campaigns.splice(i, 1);
                            console.log("Campaign " + campaignAddress + " delivered");
                            await printCampaigns()

                        } else {

                            console.log("Step " + currentStep + "delivered")

                        }
                    } else {

                        campaigns.splice(i, 1);
                        console.log("Campaign " + campaignAddress + " delivered");
                        await printCampaigns()

                    }
                    
                } else {

                    console.log("No Upkeep Needed for " + campaignAddress);
                }


            } catch (error) {
                console.error(`Error handling checkUpkeep event: ${error.message}`)
            }
    
        }

    }
     
});

/* Function that calls performUpkeep on the right campaign */
async function performUpkeepOnCampaign(i) {

    try {
        await campaigns[i].performUpkeep();
    } catch (error) {
        console.log(`Error handling performUpkeep event: ${error.message}`)
    }

}

/* Function that prints all the ongoing campaigns */
async function printCampaigns() {

    if (campaigns.length == 0) {

        console.log("Empty List")

    } else {

        console.log("List of Campaigns: ");
        campaigns.forEach(async (campaign) => {
            console.log(`Campaign Address: ${await campaign.getCampaignAddress()}, Type: ${await campaign.getCampaignType()}`);
        });

    }

}
    



