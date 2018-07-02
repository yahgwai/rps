pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RockPaperScissors.sol";
import "./RpsProxy.sol";

contract Test_RockPaperScissors_Distribute {
    struct CommitChoice {
        address playerAddress;
        bytes32 commitment;
        uint8 choice;        
    }

    uint256 public initialBalance = 10 ether;
    
    uint256 depositAmount = 25;
    uint256 betAmount = 100;
    uint256 commitAmount = depositAmount + betAmount;
    
    
    uint256 revealSpan = 10;
    uint8 rock = 1;
    uint8 paper = 2;
    uint8 scissors = 3;
    bytes32 rand1 = "abc";
    bytes32 rand2 = "123";

    function commitmentRock(address sender) private view returns (bytes32) {
        return keccak256(abi.encodePacked(sender, rock, rand1));
    }
    function commitmentPaper(address sender) private view returns (bytes32) {
        return keccak256(abi.encodePacked(sender, paper, rand2));
    }

    //TODO: maybe also consider checking that player 1 had nothing untoward occur to them

    // function testConstructorSetsRevealDeadlineSpan() public {}
    // function testConstructorSetsDepositAmount() public {}

    // function testCommitTestStoresDeposit() public {}

    // function testRevealSuccessfulFirstRevealSetsRevealDeadline() public {}
    // function testRevealSubsequentRevealsDoNotAdjustRevealDeadline() public {}
    // function testRevealCanStillBeSuccessfullyCalledAfterDeadline() public {}
    // function testRevealCannotBeCalledAfterDistribute() public {}

    function commitRevealAndDistribute (
        RpsProxy player0, RpsProxy player1,
        uint8 choice0, uint8 choice1, 
        bytes32 blind0, bytes32 blind1) public {

        //commit
        player0.commit.value(commitAmount)(keccak256(abi.encodePacked(player0, choice0, blind0)));
        player1.commit.value(commitAmount)(keccak256(abi.encodePacked(player1, choice1, blind1)));
        
        //reveal
        player0.reveal(choice0, blind0);
        player1.reveal(choice1, blind1);
        
        //distribute
        player0.distribute();
    }

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

    function assertPlayersEmpty(RockPaperScissors rps) private {
        CommitChoice memory player0 = CommitChoice(0, 0, 0);
        CommitChoice memory  player1 = CommitChoice(0, 0, 0);
        assertPlayersEqual(rps, player0, player1);
    }

    function assertStateEmptied(RockPaperScissors rps) private {
        // if all received the correct balance the contract should have been reset.
        Assert.equal(rps.revealDeadline(), 0, "Reveal deadline not reset to 0");
        Assert.equal(uint(rps.distributedWinnings()), uint(0), "Distributed winnings not reset to 0");
        assertPlayersEmpty(rps);
    }

    // paper vs rock
    function testDistributePaperBeatsRockPlayer0() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, paper, rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    function testDistributePaperBeatsRockPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, rock, paper, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, depositAmount + (2 * betAmount), "Player 1 did not receive winnings + deposit.");
        Assert.equal(address(player0).balance, depositAmount, "Player 0 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    // scissors vs paper
    function testDistributeScissorsBeatsPaperPlayer0() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, scissors, paper, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    function testDistributeScissorsBeatsPaperPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, paper, scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player0).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    // rock vs scissors
    function testDistributeRockBeatsScissorsPlayer0() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, rock, scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    function testDistributeRockBeatsScissorsPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, scissors, rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player0).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    // draws
    function testDistributeRockDrawsWithRock() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, rock, rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
        assertStateEmptied(rps);
    }

    function testDistributePaperDrawsWithPaper() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, paper, paper, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
        assertStateEmptied(rps);
    }

    function testDistributeScissorsDrawsWithScissors() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, scissors, scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
        assertStateEmptied(rps);
    }
}