//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "./TogetherForCharityToken.sol";

/* Errors */
error TogetherForCharityWithTime__TooShortDuration();
error TogetherForCharityWithTime__TooSmallDonation();
error TogetherForCharityWithTime__CampaignClosed();
error TogetherForCharityWithTime__TransferFailed();
error TogetherForCharityWithTime__UpkeepNotNeeded();

contract TogetherForCharityWithTime is AutomationCompatibleInterface {
    /* Modifiers */
    modifier CampaignClosed() {
        if (state != CampaignState.OPEN) {
            // If the campaign is close
            revert TogetherForCharityWithTime__CampaignClosed();
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
    uint256 private createdTimestamp;
    uint256 private totalTime;
    uint256 private minimumDonation;
    TogetherForCharityToken private immutable i_token;

    /* Constructor */
    constructor(
        uint256 _campaignID,
        string memory _description,
        address _creator,
        address _beneficiary,
        uint256 _amountFounded,
        uint256 _totalTime,
        uint256 _minimumAmount,
        TogetherForCharityToken token
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
        createdTimestamp = block.timestamp;
        totalTime = _totalTime;
        minimumDonation = _minimumAmount;
        i_token = token;
    }

    /* Functions */
    function fundCampaign(address funder) public payable CampaignClosed {
        if (msg.value < minimumDonation) {
            revert TogetherForCharityWithTime__TooSmallDonation();
        }

        if (funder == address(0)) {
            funders.push(msg.sender);
            fundersToAmount[msg.sender] = msg.value;
        } else {
            funders.push(funder);
            fundersToAmount[funder] = msg.value;
        }

        totalFunded += msg.value;

        emit CampaignFunded(campaignID, msg.sender, msg.value);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool timePassed = ((block.timestamp - createdTimestamp) > totalTime);
        bool isOpen = (CampaignState.OPEN == state);

        upkeepNeeded = (timePassed && isOpen);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert TogetherForCharityWithTime__UpkeepNotNeeded();
        }

        (bool success, ) = beneficiary.call{value: address(this).balance}("");
        if (!success) {
            revert TogetherForCharityWithTime__TransferFailed();
        }

        state = CampaignState.CLOSED; // Closing campaign

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

    function getCreationTimeStamp() public view returns (uint256) {
        return createdTimestamp;
    }

    function getCampaignDurationSeconds() public view returns (uint256) {
        return totalTime;
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
