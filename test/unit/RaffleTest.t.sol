// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entraceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackgaslimit;

    address public PLAYER = makeAddr("player");
    address public PLAYER_TWO = makeAddr("player_two");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entraceFee = config.entraceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackgaslimit = config.callbackgaslimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.deal(PLAYER_TWO, STARTING_PLAYER_BALANCE);
    }

    // Test into Raffle

    function testInitialRaffleStateOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEntranceFee() public view {
        assert(raffle.getEntranceFee() == entraceFee);
    }

    function testRaffleRevertWhenDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Asset
        vm.expectRevert(Raffle.Raffle__MoreEthToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testGetPlayerThatEnterRaffle() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{value: entraceFee}();

        address player = raffle.getPlayer(0);
        assert(player == PLAYER);
    }

    function testEmitRaffleEntered() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entraceFee}();
    }

    function testDontAllowEnterWhileRaffleCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);

        // Act
        raffle.performUpkeep();

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER_TWO);
        raffle.enterRaffle{value: entraceFee}();
    }

    function testCheckUpkeepReturnFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);

        // Act / Assert
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnFalseIfRaffleNotOpen() public raffleEntered {
        // Arrange
        raffle.performUpkeep();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnTrueWhenParameterAreGood()
        public
        raffleEntered
    {
        // Act / Assert
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepFalse() public {
        // Arrange
        uint256 currBalance = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        uint256 numPlayers = 0;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep();
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(raffleState) == 1);
        assert(uint256(requestId) > 0);
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 requestId
    ) public raffleEntered {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }

        // Arrange / Assert / Act
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnerAndSendMoneys()
        public
        raffleEntered
    {
       if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }

        // Arrange
        uint256 startingIndex = 1;
        uint256 additionalEntrants = 3; // Total player is 4
        address expectedWinner = address(uint160(1));
        uint256 prize = entraceFee * (startingIndex + additionalEntrants);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entraceFee}();
        }

        uint256 startingLastTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalanceWinner = expectedWinner.balance;

        // Act
        vm.deal(address(raffle), prize);
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        uint256 endingLastTimeStamp = raffle.getLastTimeStamp();
        uint256 endingBalanceWinner = expectedWinner.balance;

        assert(recentWinner == expectedWinner);
        assert(endingBalanceWinner == startingBalanceWinner + prize);
        assert(endingLastTimeStamp > startingLastTimeStamp);
    }
}
