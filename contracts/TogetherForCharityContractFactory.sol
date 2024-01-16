//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./TogetherForCharityWithTarget.sol";
import "./TogetherForCharityWithSteps.sol";
import "./TogetherForCharityWithTime.sol";

/* Errors */
error TogetherForCharityContractFactory__RegisterUpkeepFailed();
error TogetherForCharityContractFactory__TransferFailed();
error TogetherForCharityContractFactory__TooManySteps();

contract TogetherForCharityContractFactory {
    /* State Variables */
    address[] private deployedCampaigns;
    uint256 private numberOfCampaigns;

    /* Constructor */
    constructor() {
        deployedCampaigns = new address[](0);
        numberOfCampaigns = 0;
    }

    /* Functions */
    function createCampaignWithTarget(
        string memory description,
        address beneficiary,
        uint256 targetAmount,
        uint256 minimumAmount
    ) public payable {
        numberOfCampaigns += 1;
        /* Creating a new campaign with target */
        TogetherForCharityWithTarget newCampaign = new TogetherForCharityWithTarget(
                numberOfCampaigns,
                description,
                msg.sender,
                beneficiary,
                targetAmount,
                minimumAmount
            );

        deployedCampaigns.push(address(newCampaign)); // Inserting the new campaign in the list of created campaigns

        emit CampaignCreated(
            numberOfCampaigns,
            address(newCampaign),
            msg.sender,
            beneficiary,
            0 // Capaign With Target
        );

        newCampaign.fundCampaign{value: msg.value}(msg.sender); // Sending initial donation to the new campaign

        emit EthSentToCampaign(
            numberOfCampaigns,
            address(newCampaign),
            msg.value
        );
    }

    function createCampaignWithTime(
        string memory description,
        address beneficiary,
        uint256 totalTime,
        uint256 minimumAmount
    ) public payable {
        numberOfCampaigns += 1;
        /* Creating a new campaign with time */
        TogetherForCharityWithTime newCampaign = new TogetherForCharityWithTime(
            numberOfCampaigns,
            description,
            msg.sender,
            beneficiary,
            totalTime,
            minimumAmount
        );

        deployedCampaigns.push(address(newCampaign)); // Inserting the new campaign in the list of created campaigns

        emit CampaignCreated(
            numberOfCampaigns,
            address(newCampaign),
            msg.sender,
            beneficiary,
            1 // Capaign With Time
        );

        newCampaign.fundCampaign{value: msg.value}(msg.sender); // Sending initial donation to the new campaign

        emit EthSentToCampaign(
            numberOfCampaigns,
            address(newCampaign),
            msg.value
        );
    }

    function createCampaignWithSteps(
        string memory description,
        address beneficiary,
        uint256 minimumAmount,
        uint256 targetAmount,
        uint16 steps,
        uint256 stepTimeInterval
    ) public payable {
        /* No more than 5 steps allowed */
        if (steps > 5) {
            revert TogetherForCharityContractFactory__TooManySteps();
        }
        numberOfCampaigns += 1;
        /* Creating a new campaign with steps */
        TogetherForCharityWithSteps newCampaign = new TogetherForCharityWithSteps(
                numberOfCampaigns,
                description,
                msg.sender,
                beneficiary,
                minimumAmount,
                targetAmount,
                steps,
                stepTimeInterval
            );

        deployedCampaigns.push(address(newCampaign)); // Inserting the new campaign in the list of created campaigns

        emit CampaignCreated(
            numberOfCampaigns,
            address(newCampaign),
            msg.sender,
            beneficiary,
            2 // Capaign With Steps
        );

        newCampaign.fundCampaign{value: msg.value}(msg.sender); // Sending initial donation to the new campaign

        emit EthSentToCampaign(
            numberOfCampaigns,
            address(newCampaign),
            msg.value
        );
    }

    /* Getters */
    function getDeployedCampaigns() public view returns (address[] memory) {
        return deployedCampaigns;
    }

    function getNumberOfCampaigns() public view returns (uint256) {
        return numberOfCampaigns;
    }

    /* Events */
    event CampaignCreated(
        uint256 campaignID,
        address indexed campaignAddress,
        address indexed creator,
        address indexed beneficiary,
        uint8 campaignType
    );

    event EthSentToCampaign(
        uint256 campaignID,
        address indexed campaignAddress,
        uint256 amount
    );
}
