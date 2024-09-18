// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";

contract RaffleTest is Test {
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
}
