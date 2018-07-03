pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./ExecutionProxy.sol";
import "../contracts/RockPaperScissors.sol";
import "./RpsProxy.sol";

contract Test_RockPaperScissors_DistributeExtendedMore {
    struct CommitChoice {
        address playerAddress;
        bytes32 commitment;
        uint8 choice;        
    }

    uint256 public initialBalance = 20 ether;
    
    uint256 depositAmount = 25;
    uint256 betAmount = 100;
    uint256 commitAmount = depositAmount + betAmount;
    
    uint256 revealSpan = 10;
    uint8 rock = 1;
    uint8 paper = 2;
    uint8 scissors = 3;
    bytes32 rand1 = "abc";
    bytes32 rand2 = "123";

    function assertPlayersEqual(RockPaperScissors rps, CommitChoice player0, CommitChoice player1) private {
        address playerAddress0;
        bytes32 commitment0;
        uint8 choice0;
        (playerAddress0, commitment0, choice0) = rps.players(0);

        address playerAddress1;
        bytes32 commitment1;
        uint8 choice1;
        (playerAddress1, commitment1, choice1) = rps.players(1);

        Assert.equal(playerAddress0, player0.playerAddress, "Player 0 address does not equal supplied one.");
        Assert.equal(uint(choice0), uint(player0.choice), "Player 0 choice does not equal supplied one.");
        Assert.equal(commitment0, player0.commitment, "Player 0 commitment does not equal supplied one.");

        Assert.equal(playerAddress1, player1.playerAddress, "Player 1 address does not equal supplied one.");
        Assert.equal(uint(choice1), uint(player1.choice), "Player 1 choice does not equal supplied one.");
        Assert.equal(commitment1, player1.commitment, "Player 1 commitment does not equal supplied one.");
    }

    function testWinningsAreDistributedWhenOnePlayer0CannotReceive() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);

        //commit
        bytes32 commitment0 = keccak256(abi.encodePacked(player0, rock, rand1));
        bytes32 commitment1 = keccak256(abi.encodePacked(player1, rock, rand2));
        RockPaperScissors(player0).commit.value(commitAmount)(commitment0);
        player0.execute();
        player1.commit.value(commitAmount)(commitment1);

        //reveal
        RockPaperScissors(player0).reveal(rock, rand1);
        player0.execute();
        player1.reveal(rock, rand2);
        
        //distribute
        player1.distribute();

        // payer 1 should have funds, player 0 should not as we cant send money to an execution proxy - the fallback has been overridden with storage
        Assert.equal(address(player1).balance, commitAmount, "Player 1 did not receive correct amount.");
        Assert.equal(address(player0).balance, 0, "Player 0 should not receive any amount.");
        Assert.equal(uint(rps.distributedWinnings()), uint(0x06), "Winning should only be distributed to player 1.");
        assertPlayersEqual(rps, CommitChoice(player0, commitment0, rock), CommitChoice(player1, commitment1, rock));
    }

    function testWinningsAreDistributedWhenOnePlayer1CannotReceive() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);

        //commit
        bytes32 commitment0 = keccak256(abi.encodePacked(player0, rock, rand1));
        bytes32 commitment1 = keccak256(abi.encodePacked(player1, rock, rand2));
        player0.commit.value(commitAmount)(commitment0);
        RockPaperScissors(player1).commit.value(commitAmount)(commitment1);
        player1.execute();
        

        //reveal
        player0.reveal(rock, rand1);
        RockPaperScissors(player1).reveal(rock, rand2);
        player1.execute();
        
        //distribute
        player0.distribute();

        // // payer 1 should have funds, player 0 should not as we cant send money to an execution proxy - the fallback has been overridden with storage
        Assert.equal(address(player0).balance, commitAmount, "Player 0 did not receive correct amount.");
        Assert.equal(address(player1).balance, 0, "Player 1 should not receive any amount.");
        Assert.equal(uint(rps.distributedWinnings()), uint(0x60), "Winning should only be distributed to player 0.");
        assertPlayersEqual(rps, CommitChoice(player0, commitment0, rock), CommitChoice(player1, commitment1, rock));
    }

    //TODO: maybe also consider checking that player 1 had nothing untoward occur to them

    // function testCommitTestStoresDeposit() public {}

    // function testRevealSuccessfulFirstRevealSetsRevealDeadline() public {}
    // function testRevealSubsequentRevealsDoNotAdjustRevealDeadline() public {}
    // function testRevealCanStillBeSuccessfullyCalledAfterDeadline() public {}
    // function testRevealCannotBeCalledAfterDistribute() public {}

    // function testFullFlowCanOccurWithoutDeposit() public {}
    // function testFullFlowCanOccurWithoutBet() public {}
}