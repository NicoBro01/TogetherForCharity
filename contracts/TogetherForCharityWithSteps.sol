//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/* Errors */
error TogetherForCharityWithSteps__CampaignClosed(uint256);
error TogetherForCharityWithSteps__CampaignOpen(uint256);
error TogetherForCharityWithSteps__TooSmallDonation();
error TogetherForCharityWithSteps__TransferFailed(address, uint256);
error TogetherForCharityWithSteps__IsNotVoter(address);
error TogetherForCharityWithSteps__VoteNotNeeded();
error TogetherForCharityWithSteps__AlreadyVoted(address);
error TogetherForCharityWithSteps__UpkeepNotNeeded();

contract TogetherForCharityWithSteps {
    /* Modifiers */
    /* Campaign MUST be open */
    modifier CampaignOpen() {
        if (state != CampaignState.OPEN) {
            revert TogetherForCharityWithSteps__CampaignClosed(campaignID);
        }
        _;
    }

    /* Campaign MUST be closed */
    modifier CampaignClosed() {
        if (state != CampaignState.CLOSED) {
            revert TogetherForCharityWithSteps__CampaignOpen(campaignID);
        }
        _;
    }

    /* Check if an address funded the campaign and so if it can vote */
    modifier CanVote(address voter) {
        if (currentStep == 0) {
            revert TogetherForCharityWithSteps__VoteNotNeeded();
        } else {
            bool found = false;

            for (uint256 i = 0; i < allowedVotersCurrentStep.length; i++) {
                if (allowedVotersCurrentStep[i] == voter) {
                    found = true;
                }
            }
            if (found == false) {
                revert TogetherForCharityWithSteps__IsNotVoter(voter);
            }
        }
        _;
    }

    /* Check if an address already voted */
    modifier NotAlreadyVoted(address voter) {
        if (
            (votes[currentStep][voter] == VoteType.TRUE) ||
            (votes[currentStep][voter] == VoteType.FALSE)
        ) {
            revert TogetherForCharityWithSteps__AlreadyVoted(voter);
        }
        _;
    }

    /* Type declarations */
    enum CampaignState {
        OPEN,
        CLOSED
    }

    enum VoteType {
        NOT_VOTED,
        TRUE,
        FALSE
    }

    /* Campaign Variables */
    uint256 private campaignID;
    string private description;
    address private creator;
    CampaignState private state;
    address payable private beneficiary;
    address[] private funders;
    address[] private allowedVotersCurrentStep; // List of addresses allowed to vote in the current step
    address[] private allowedVotersNextStep; // List of addresses allowed to vote in the next step
    mapping(address => uint256) private fundersToAmount; // Return how much an address donates in Wei
    mapping(uint16 => mapping(address => VoteType)) private votes; // For each step there is a mapping from the voter to the vote
    uint256 private totalFunded;
    uint256 private targetAmount; // Target amount in Wei that has to be achieved to pass at the first step
    uint256 private createdTimestamp; // Timestamp of the contract creation
    uint256 private newStepTimestamp; // Timestamp of the current step starting
    uint256 private maxTime; // Max time to achieve the target amount. If time runs out, first step will start
    uint16 private currentStep;
    uint16 private steps; // Total number of steps
    uint256 private stepTimeInterval; // How long each step will last
    uint256 private minimumDonation;

    /* Constructor */
    constructor(
        uint256 _campaignID,
        string memory _description,
        address _creator,
        address _beneficiary,
        uint256 _minimumAmount,
        uint256 _targetAmount,
        uint16 _steps,
        uint256 _stepTimeInterval
    ) {
        campaignID = _campaignID;
        description = _description;
        creator = _creator;
        state = CampaignState.OPEN;
        beneficiary = payable(_beneficiary);
        totalFunded = 0;
        targetAmount = _targetAmount;
        createdTimestamp = block.timestamp;
        maxTime = 789 * (10 ** 4); // 3 month in seconds
        stepTimeInterval = _stepTimeInterval;
        minimumDonation = _minimumAmount;
        currentStep = 0;
        steps = _steps;
    }

    /* Functions */

    /* Function to donate */
    function fundCampaign(address funder) public payable CampaignOpen {
        if (msg.value < minimumDonation) {
            revert TogetherForCharityWithSteps__TooSmallDonation();
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

        /* If target is achieved, it closes the campaign and delivers the first amount based on the number of steps */
        if (totalFunded >= targetAmount) {
            state = CampaignState.CLOSED;
            deliverStep();
        }
    }

    /* Function that will deliver a portion of the donated amount */
    function deliverStep() internal CampaignClosed {
        /* Calculating the total amount to send */
        uint256 amountToSend = address(this).balance / (steps - currentStep);

        /* Sending amount */
        (bool success, ) = beneficiary.call{value: amountToSend}("");
        if (!success) {
            revert TogetherForCharityWithSteps__TransferFailed(
                beneficiary,
                amountToSend
            );
        } else {
            emit StepDelivered(
                campaignID,
                beneficiary,
                amountToSend,
                currentStep + 1
            );
        }

        if (currentStep == 0) {
            /* Inserting all funders in allowedVotersCurrentStep array */
            for (uint256 i = 0; i < funders.length; i++) {
                allowedVotersCurrentStep.push(funders[i]);
            }
        } else if (currentStep > 0) {
            /* Inserting all funders who have not voted in the current step in allowedVotersNextStep array */
            for (uint256 i = 0; i < allowedVotersCurrentStep.length; i++) {
                if (
                    votes[currentStep][allowedVotersCurrentStep[i]] ==
                    VoteType.NOT_VOTED
                ) {
                    allowedVotersNextStep.push(allowedVotersCurrentStep[i]);
                }
            }

            /* Cleaning the array */
            allowedVotersCurrentStep = new address[](0);

            /* Switching arrays */
            for (uint256 i = 0; i < allowedVotersNextStep.length; i++) {
                allowedVotersCurrentStep.push(allowedVotersNextStep[i]);
            }

            allowedVotersNextStep = new address[](0);
        }

        /* Starting a new step */
        currentStep++;
        newStepTimestamp = block.timestamp;
    }

    /* Function to vote if continue the campaign or left it
       It will refund all voters who voted false */
    function voteForNextStep(
        bool vote
    ) public CanVote(msg.sender) NotAlreadyVoted(msg.sender) CampaignClosed {
        if (vote == true) {
            votes[currentStep][msg.sender] = VoteType.TRUE;
            allowedVotersNextStep.push(msg.sender);
        } else if (vote == false) {
            votes[currentStep][msg.sender] = VoteType.FALSE;
            uint256 amountToSend = fundersToAmount[msg.sender] - // Calculating how much to return to the funder
                ((fundersToAmount[msg.sender] / steps) * currentStep);

            /* Refunding funder */
            (bool success, ) = msg.sender.call{value: amountToSend}("");
            if (!success) {
                revert TogetherForCharityWithSteps__TransferFailed(
                    msg.sender,
                    amountToSend
                );
            }

            /* Updating structures */
            fundersToAmount[msg.sender] -= amountToSend;
            totalFunded -= amountToSend;

            emit FunderRefunded(campaignID, msg.sender, amountToSend);
        }
    }

    /* Function that returns true if maxTime has passed if it's in the donation step
       or returns true if newStepTimestap has passed if it's in some step */
    function checkUpkeep() public view returns (bool) {
        if (currentStep == 0) {
            bool timePassed = ((block.timestamp - createdTimestamp) > maxTime);
            bool isOpen = (CampaignState.OPEN == state);

            return (timePassed && isOpen);
        } else if (currentStep > 0) {
            bool timePassed = ((block.timestamp - newStepTimestamp) >
                stepTimeInterval);
            bool isClosed = (CampaignState.CLOSED == state);

            return (timePassed && isClosed);
        }
    }

    /* Function that calls deliverStep() if checkUpkeep returns true */
    function performUpkeep() public {
        bool upkeepNeeded = checkUpkeep();

        if (!upkeepNeeded) {
            revert TogetherForCharityWithSteps__UpkeepNotNeeded();
        }

        /* Closing campaign if it's open */
        if (CampaignState.OPEN == state) {
            state = CampaignState.CLOSED;
        }

        deliverStep();
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

    function getCampaignState() public view returns (string memory) {
        if (state == CampaignState.OPEN) {
            return "Open";
        } else {
            return "Closed";
        }
    }

    function getBeneficiary() public view returns (address) {
        return beneficiary;
    }

    function getFunders() public view returns (address[] memory) {
        return funders;
    }

    function getAllowedVotersForCurrentStep()
        public
        view
        returns (address[] memory)
    {
        return allowedVotersCurrentStep;
    }

    function getAllowedVotersForNextStep()
        public
        view
        returns (address[] memory)
    {
        return allowedVotersNextStep;
    }

    function getAmountFundedFromFunder(
        address _funder
    ) public view returns (uint256) {
        return fundersToAmount[_funder];
    }

    function getVoteForCurrentStep(
        uint16 _step,
        address _voter
    ) public view returns (VoteType) {
        return votes[_step][_voter];
    }

    function getTotalAmountFunded() public view returns (uint256) {
        return totalFunded;
    }

    function getTargetAmount() public view returns (uint256) {
        return targetAmount;
    }

    function getTimestampOfCreation() public view returns (uint256) {
        return createdTimestamp;
    }

    function getCurrentStepInitialTimestamp() public view returns (uint256) {
        return newStepTimestamp;
    }

    function getMaxDurationTimeInSeconds() public view returns (uint256) {
        return maxTime;
    }

    function getTotalSteps() public view returns (uint16) {
        return steps;
    }

    function getCurrentStep() public view returns (uint16) {
        return currentStep;
    }

    function getStepDurationInSeconds() public view returns (uint256) {
        return stepTimeInterval;
    }

    function getMinimumDonation() public view returns (uint256) {
        return minimumDonation;
    }

    function getCampaignAddress() public view returns (address) {
        return address(this);
    }

    function getCampaignType() public pure returns (string memory) {
        return "Steps";
    }

    /* Events */
    event CampaignFunded(
        uint256 indexed campaignID,
        address indexed funder,
        uint256 amount
    );
    event StepDelivered(
        uint256 indexed campaignID,
        address indexed beneficiary,
        uint256 amount,
        uint16 step
    );
    event FunderRefunded(
        uint256 indexed campaignID,
        address indexed funder,
        uint256 amount
    );
}
