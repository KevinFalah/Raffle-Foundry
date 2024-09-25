// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {CreateSubscription, FundSubscription} from "script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionsTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entraceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackgaslimit;
    address account;
    address link;

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entraceFee = config.entraceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackgaslimit = config.callbackgaslimit;
        account = config.account;
        link = config.link;
    }

    function testSuccessGetSubscriptionId() public {
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 exampleSubId, address vrfExample) = createSubscription.createSubscription(vrfCoordinator, account);

        assert(exampleSubId > 0);
        assert(vrfExample != address(0));
    }

    function testFundSubscription() public {
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, account);

        uint256 expectedFundAmount = 3 ether * 500;
        //  assertEq(VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscriptionFunds(subscriptionId), expectedFundAmount);
        // assertEq(VRFCoordinatorV2_5Mock(vrfCoordinator).);
    }
}
