//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TogetherForCharityWithTime.sol";
import "./TogetherForCharityWithTarget.sol";
import "./TogetherForCharityToken.sol";

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

interface AutomationRegistrarInterface {
    function registerUpkeep(
        RegistrationParams calldata requestParams
    ) external returns (uint256);
}

error TogetherForCharityContractFactory__RegisterUpkeepFailed();
error TogetherForCharityContractFactory__TransferFailed();
error TogetherForCharityContractFactory__AllowanceFailed();

contract TogetherForCharityContractFactory {
    /* State Variables */
    LinkTokenInterface private immutable i_link;
    AutomationRegistrarInterface private immutable i_registrar;
    TogetherForCharityToken private immutable i_token;
    mapping(address => uint256) private campaignAddressToUpkeepID;
    uint32 private gasLimit;
    uint96 private constant LINK_AMOUNT = 1 * (10 ** 18);
    uint256 private constant NEW_MINT_AMOUNT = 1000000 * (10 ** 18);

    address[] private deployedCampaigns;
    uint256 private numberOfCampaigns;

    /* Constructor */
    constructor(
        LinkTokenInterface link,
        AutomationRegistrarInterface registrar,
        uint32 _gasLimit
    ) {
        i_link = link;
        i_registrar = registrar;
        i_token = new TogetherForCharityToken();
        gasLimit = _gasLimit;

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
        TogetherForCharityWithTarget newCampaign = new TogetherForCharityWithTarget(
                numberOfCampaigns,
                description,
                msg.sender,
                beneficiary,
                msg.value,
                targetAmount,
                minimumAmount
            );

        deployedCampaigns.push(address(newCampaign));

        emit CampaignCreated(
            numberOfCampaigns,
            address(newCampaign),
            msg.sender,
            beneficiary
        );
    }

    function createCampaignWithTime(
        string memory description,
        address beneficiary,
        uint256 totalTime,
        uint256 minimumAmount
    ) public payable {
        if (i_token.balanceOf(address(this)) < 10) {
            i_token._mint(address(this), NEW_MINT_AMOUNT);
        }

        numberOfCampaigns += 1;
        TogetherForCharityWithTime newCampaign = new TogetherForCharityWithTime(
            numberOfCampaigns,
            description,
            msg.sender,
            beneficiary,
            msg.value,
            totalTime,
            minimumAmount,
            i_token
        );

        bool approved = i_token.approve(
            address(newCampaign),
            i_token.balanceOf(address(this))
        );

        if (!approved) {
            revert TogetherForCharityContractFactory__AllowanceFailed();
        }

        RegistrationParams memory newRegistrationParams = RegistrationParams(
            string.concat("Campaign ", Strings.toString(numberOfCampaigns)),
            "0x",
            address(newCampaign),
            gasLimit,
            address(this),
            0,
            "0x",
            "0x",
            "0x",
            LINK_AMOUNT
        );

        registerAndPredictID(newRegistrationParams);

        deployedCampaigns.push(address(newCampaign));

        emit CampaignCreated(
            numberOfCampaigns,
            address(newCampaign),
            msg.sender,
            beneficiary
        );

        newCampaign.fundCampaign{value: msg.value}(msg.sender);

        emit EthSentToCampaign(
            numberOfCampaigns,
            address(newCampaign),
            msg.value
        );
    }

    function registerAndPredictID(RegistrationParams memory params) internal {
        i_link.approve(address(i_registrar), params.amount);
        uint256 upkeepID = i_registrar.registerUpkeep(params);

        if (upkeepID != 0) {
            campaignAddressToUpkeepID[params.upkeepContract] = upkeepID;
        } else {
            revert TogetherForCharityContractFactory__RegisterUpkeepFailed();
        }
    }

    function getLinkTokenInterface() public view returns (LinkTokenInterface) {
        return i_link;
    }

    function getAutomationRegistrarInterface()
        public
        view
        returns (AutomationRegistrarInterface)
    {
        return i_registrar;
    }

    function getUpkeepIDFromCampaignAddress(
        address _campaignAddress
    ) public view returns (uint256) {
        return campaignAddressToUpkeepID[_campaignAddress];
    }

    function getGasLimit() public view returns (uint256) {
        return gasLimit;
    }

    function getLinkAmountToSendToKeepers() public pure returns (uint96) {
        return LINK_AMOUNT;
    }

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
        address indexed beneficiary
    );

    event EthSentToCampaign(
        uint256 campaignID,
        address indexed campaignAddress,
        uint256 amount
    );
}
