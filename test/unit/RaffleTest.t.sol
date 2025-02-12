// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "lib/forge-std/src/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesOpenStat() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__sendMoreEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // arrange
        vm.prank(PLAYER);
        // act
        raffle.enterRaffle{value: entranceFee}();
        // assert
        address playerRecord = raffle.getPlayers(0);
        assert(playerRecord == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        //arrange
        vm.prank(PLAYER);
        //act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    // function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
    //     //Arrange
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);
    //     raffle.performUpkeep("");
    //     //Act  //Assert
    //     vm.expectRevert(Raffle.Raffle__isNotOpen.selector);
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee};
    // }

    //check upkeep//
    function testCheckUpkeepReturnFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    // function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
    //     public
    //     raffleEntered
    //     skipFork
    // {
    //     address expectedWinner = address(1);

    //     // Arrange
    //     uint256 additionalEntrances = 3;
    //     uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

    //     for (
    //         uint256 i = startingIndex;
    //         i < startingIndex + additionalEntrances;
    //         i++
    //     ) {
    //         address player = address(uint160(i));
    //         hoax(player, 1 ether); // deal 1 eth to the player
    //         raffle.enterRaffle{value: entranceFee}();
    //     }

    //     uint256 startingTimeStamp = raffle.getLastTimeStamp();
    //     uint256 startingBalance = expectedWinner.balance;

    //     // Act
    //     vm.recordLogs();
    //     raffle.performUpkeep(""); // emits requestId
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     console2.logBytes32(entries[1].topics[1]);
    //     bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

    //     VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
    //         uint256(requestId),
    //         address(raffle)
    //     );

    //     // Assert
    //     address recentWinner = raffle.getRecentWinner();
    //     Raffle.RaffleState raffleState = raffle.getRaffleState();
    //     uint256 winnerBalance = recentWinner.balance;
    //     uint256 endingTimeStamp = raffle.getLastTimeStamp();
    //     uint256 prize = entranceFee * (additionalEntrances + 1);

    //     assert(recentWinner == expectedWinner);
    //     assert(uint256(raffleState) == 0);
    //     assert(winnerBalance == startingBalance + prize);
    //     assert(endingTimeStamp > startingTimeStamp);
    // }
}
