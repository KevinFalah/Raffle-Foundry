// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
// import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

// @title A Sample Raffle COntract
// @author Kevin Falah
// @notice This contract is for creating a sample raffle
// @dev Implements Chainlink contract 

contract Raffle is VRFConsumerBaseV2Plus {

    error Raffle__MoreEthToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint256 private immutable i_entranceFee;
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    event raffleEntered (address indexed player);
    event winnerPicked (address indexed winner);

    constructor (uint256 entraceFee, uint256 interval, address _vrfCoordinator, bytes32 gasLane, uint256 subscriptionId, uint32 callbackgaslimit) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = entraceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackgaslimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__MoreEthToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit raffleEntered(msg.sender);
    }

    function pickWinner() public {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
       s_raffleState = RaffleState.CALCULATING;

       uint256 requestId = s_vrfCoordinator.requestRandomWords(
           VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            }) 
        );

    }

  function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
    s_raffleState = RaffleState.OPEN;

    (bool sent, ) = recentWinner.call{value: address(this).balance}("");
    if (!sent) {
        revert Raffle__TransferFailed();
    }

    emit winnerPicked(recentWinner);
  }

    // Getter Functions

    function getEntranceFee() external returns (uint256) {

    }
}

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
