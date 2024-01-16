//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/* Errors */
error TogetherForCharityWithTime__TooShortDuration();
error TogetherForCharityWithTime__TooSmallDonation();
error TogetherForCharityWithTime__CampaignClosed(uint256);
error TogetherForCharityWithTime__TransferFailed();
error TogetherForCharityWithTime__UpkeepNotNeeded();

contract TogetherForCharityWithTime {
    /* Modifiers */

    /* Campaign MUST be open */
    modifier CampaignOpen() {
        if (state != CampaignState.OPEN) {
            revert TogetherForCharityWithTime__CampaignClosed(campaignID);
        }
        _;
    }

    /* Type declarations */
    enum CampaignState {
        OPEN,
        CLOSED
    }

    /* Campaign Variables */
    uint256 private campaignID;
    string private description;
    address private creator;
    CampaignState private state;
    address payable private beneficiary;
    address[] private funders;
    mapping(address => uint256) private fundersToAmount; // Return how much an address donates in Wei
    uint256 private totalFunded;
    uint256 private createdTimestamp; // Timestamp of the contract creation
    uint256 private totalTime; // Total time that campaign will runs. When time runs out, the campaign will be delivered
    uint256 private minimumDonation;

    /* Constructor */
    constructor(
        uint256 _campaignID,
        string memory _description,
        address _creator,
        address _beneficiary,
        uint256 _totalTime,
        uint256 _minimumAmount
    ) {
        campaignID = _campaignID;
        description = _description;
        creator = _creator;
        state = CampaignState.OPEN;
        beneficiary = payable(_beneficiary);
        totalFunded = 0;
        createdTimestamp = block.timestamp;
        totalTime = _totalTime;
        minimumDonation = _minimumAmount;
    }

    /* Functions */

    /* Function to donate */
    function fundCampaign(address funder) public payable CampaignOpen {
        if (msg.value < minimumDonation) {
            revert TogetherForCharityWithTime__TooSmallDonation();
        }

        /* Check if an address has already donated */
        if (fundersToAmount[funder] == 0) {
            funders.push(funder);
            fundersToAmount[funder] = msg.value;
        } else {
            fundersToAmount[funder] += msg.value;
        }

        totalFunded += msg.value;

        emit CampaignFunded(campaignID, msg.sender, msg.value);
    }

    /* Function that returns true if campaign is open and total time has passed */
    function checkUpkeep() public view returns (bool) {
        bool timePassed = ((block.timestamp - createdTimestamp) > totalTime);
        bool isOpen = (CampaignState.OPEN == state);

        return (timePassed && isOpen);
    }

    /* Function that sends money to beneficiary if checkUpkeep returns true */
    function performUpkeep() public {
        bool upkeepNeeded = checkUpkeep();

        if (!upkeepNeeded) {
            revert TogetherForCharityWithTime__UpkeepNotNeeded();
        }

        /* Sending amount */
        (bool success, ) = beneficiary.call{value: address(this).balance}("");
        if (!success) {
            revert TogetherForCharityWithTime__TransferFailed();
        }

        state = CampaignState.CLOSED; // Closing campaign

        emit CampaignDelivered(campaignID, beneficiary, totalFunded);
    }

    /* Getters */

    function getCampaignID() public view returns (uint256) {
        return campaignID;
    }

    function getDescription() public view returns (string memory) {
        return description;
    }

    function getCreator() public view returns (address) {
        return creator;
    }

    function getCampaignState() public view returns (CampaignState) {
        return state;
    }

    function getBeneficiary() public view returns (address) {
        return beneficiary;
    }

    function getFunders() public view returns (address[] memory) {
        return funders;
    }

    function getAmountFundedFromFunder(
        address _funder
    ) public view returns (uint256) {
        return fundersToAmount[_funder];
    }

    function getTotalAmountFunded() public view returns (uint256) {
        return totalFunded;
    }

    function getCreationTimeStamp() public view returns (uint256) {
        return createdTimestamp;
    }

    function getCampaignDurationSeconds() public view returns (uint256) {
        return totalTime;
    }

    function getMinimumDonation() public view returns (uint256) {
        return minimumDonation;
    }

    function getCampaignAddress() public view returns (address) {
        return address(this);
    }

    function getCampaignType() public pure returns (string memory) {
        return "Time";
    }

    /* Events */
    event CampaignFunded(
        uint256 indexed campaignID,
        address indexed funder,
        uint256 amount
    );
    event CampaignDelivered(
        uint256 indexed campaignID,
        address indexed beneficiary,
        uint256 amount
    );
}
