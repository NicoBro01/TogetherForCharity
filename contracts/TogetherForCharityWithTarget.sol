//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/* Errors */
error TogetherForCharityWithTarget__TooSmallDonation();
error TogetherForCharityWithTarget__CampaignClosed();
error TogetherForCharityWithTarget__TransferFailed();

contract TogetherForCharityWithTarget {
    /* Modifiers */
    modifier CampaignClosed() {
        if (state != CampaignState.OPEN) {
            // If the campaign is close
            revert TogetherForCharityWithTarget__CampaignClosed();
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
    mapping(address => uint256) private fundersToAmount;
    uint256 private totalFunded;
    uint256 private targetAmount;
    uint256 private minimumDonation;

    /* Constructor */
    constructor(
        uint256 _campaignID,
        string memory _description,
        address _creator,
        address _beneficiary,
        uint256 _amountFounded,
        uint256 _targetAmount,
        uint256 _minimumAmount
    ) {
        campaignID = _campaignID;
        description = _description;
        creator = _creator;
        state = CampaignState.OPEN;
        beneficiary = payable(_beneficiary);
        funders = new address[](0);
        funders.push(_creator);
        fundersToAmount[_creator] = _amountFounded;
        totalFunded = _amountFounded;
        targetAmount = _targetAmount;
        minimumDonation = _minimumAmount;
    }

    /* Functions */
    function fundCampaign() public payable CampaignClosed {
        if (msg.value < minimumDonation) {
            revert TogetherForCharityWithTarget__TooSmallDonation();
        }

        funders.push(msg.sender);
        fundersToAmount[msg.sender] = msg.value;
        totalFunded += msg.value;

        emit CampaignFunded(campaignID, msg.sender, msg.value);

        if (totalFunded >= targetAmount) {
            deliverCampaign();
        }
    }

    function deliverCampaign() internal CampaignClosed {
        (bool success, ) = beneficiary.call{value: totalFunded}("");
        if (!success) {
            revert TogetherForCharityWithTarget__TransferFailed();
        }

        state = CampaignState.CLOSED; // Campaign Closed

        emit CampaignDelivered(campaignID, beneficiary, totalFunded);
    }

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
