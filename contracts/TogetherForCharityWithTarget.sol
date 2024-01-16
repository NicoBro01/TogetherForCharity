//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/* Errors */
error TogetherForCharityWithTarget__TooSmallDonation();
error TogetherForCharityWithTarget__CampaignClosed(uint256);
error TogetherForCharityWithTarget__TransferFailed(address, uint256);
error TogetherForCharityWithTarget__UpkeepNotNeeded();

contract TogetherForCharityWithTarget {
    /* Modifiers */

    /* Campaign MUST be open */
    modifier CampaignOpen() {
        if (state != CampaignState.OPEN) {
            revert TogetherForCharityWithTarget__CampaignClosed(campaignID);
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
    uint256 private maxTime; // Max time to achieve the target amount. If time runs out, funds will be returned to funders
    uint256 private targetAmount; // Target amount in Wei that has to be achieved to be sent to the beneficiary
    uint256 private minimumDonation;

    /* Constructor */
    constructor(
        uint256 _campaignID,
        string memory _description,
        address _creator,
        address _beneficiary,
        uint256 _targetAmount,
        uint256 _minimumAmount
    ) {
        campaignID = _campaignID;
        description = _description;
        creator = _creator;
        state = CampaignState.OPEN;
        beneficiary = payable(_beneficiary);
        totalFunded = 0;
        createdTimestamp = block.timestamp;
        maxTime = 789 * (10 ** 4); // 3 month in seconds
        targetAmount = _targetAmount;
        minimumDonation = _minimumAmount;
    }

    /* Functions */

    /* Function to donate */
    function fundCampaign(address funder) public payable CampaignOpen {
        if (msg.value < minimumDonation) {
            revert TogetherForCharityWithTarget__TooSmallDonation();
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

        /* If target is achieved, it calls deliverCampaign() */
        if (totalFunded >= targetAmount) {
            deliverCampaign();
        }
    }

    /* Function that sends funds to the beneficiary */
    function deliverCampaign() internal CampaignOpen {
        (bool success, ) = beneficiary.call{value: address(this).balance}("");
        if (!success) {
            revert TogetherForCharityWithTarget__TransferFailed(
                beneficiary,
                address(this).balance
            );
        }

        state = CampaignState.CLOSED; // Campaign Closed

        emit CampaignDelivered(campaignID, beneficiary, totalFunded);
    }

    /* Function that returns true if campaign is open and total time has passed */
    function checkUpkeep() public view returns (bool) {
        bool timePassed = ((block.timestamp - createdTimestamp) > maxTime);
        bool isOpen = (CampaignState.OPEN == state);

        return (timePassed && isOpen);
    }

    /* Function that sends money back to funders if checkUpkeep returns true */
    function performUpkeep() public {
        bool upkeepNeeded = checkUpkeep();

        if (!upkeepNeeded) {
            revert TogetherForCharityWithTarget__UpkeepNotNeeded();
        }

        /* Sending money back to all funders */
        for (uint256 i = 0; i < funders.length; i++) {
            (bool success, ) = funders[i].call{
                value: fundersToAmount[funders[i]]
            }("");
            if (!success) {
                revert TogetherForCharityWithTarget__TransferFailed(
                    funders[i],
                    fundersToAmount[funders[i]]
                );
            }
        }

        state = CampaignState.CLOSED; // Closing campaign

        emit CampaignNotDelivered(campaignID, beneficiary);
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

    function getTargetAmount() public view returns (uint256) {
        return targetAmount;
    }

    function getMinimumDonation() public view returns (uint256) {
        return minimumDonation;
    }

    function getMaxCampaignDurationSeconds() public view returns (uint256) {
        return maxTime;
    }

    function getCampaignAddress() public view returns (address) {
        return address(this);
    }

    function getCampaignType() public pure returns (string memory) {
        return "Target";
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
    event CampaignNotDelivered(
        uint256 indexed campaignID,
        address indexed beneficiary
    );
}
