// Layout of Contract File:
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title Lottery Contract
/// @author Rayyan Uddin
/// @notice This contract is a raffle lottery ticket contract
/// @dev Implements Chainlink VRFv2.5

contract Raffle is VRFConsumerBaseV2Plus {
    //Errors
    error Raffle__sendMoreEth();
    error Raffle__transferFail();
    error Raffle__isNotOpen();
    error Raffle__upkeepnotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    // Type declaration
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    //State Variables
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORD = 1;
    uint256 private immutable i_entrancePrice;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    RaffleState private s_raffleState = RaffleState.OPEN; //start as open

    //Events
    event RaffleEntered(address indexed player);

    //Constructor
    constructor(
        uint256 entrancePrice,
        uint256 interval,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        uint256 subscriptionId,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entrancePrice = entrancePrice;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        // @dev duration of lottery in seconds
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        // s_vrfCoordinator.requestRandomWords();
    }

    //Functions
    function enterRaffle() external payable {
        if (msg.value < i_entrancePrice) {
            revert Raffle__sendMoreEth();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__isNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev chainlink node will call this function to check if the lottery
     * is ready to have a winner picked.
     * following should be true if upkeepNeeded is true.
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - upKeepNeeded - true if it's time to restart a lottry else false.
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasPlayers;
        return (upkeepNeeded, "");
    }

    // get a random number
    // check if enough time has passed
    function performUpkeep(bytes calldata /* performData */) external {
        //check if enough time passed to pickwinner
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__upkeepnotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORD,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__transferFail();
        }
    }

    /**
     * Getter function
     */
    function getEntrancePrice() external view returns (uint256) {
        return i_entrancePrice;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 playerIndex) external view returns (address) {
        return s_players[playerIndex];
    }
}
