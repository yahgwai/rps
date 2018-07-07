pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RockPaperScissors.sol";
import "./ExecutionProxy.sol";
import "./RpsProxy.sol";

contract Test_RockPaperScissors_Distribute {
    uint256 public initialBalance = 10 ether;
    
    uint256 depositAmount = 25;
    uint256 betAmount = 100;
    uint256 commitAmount = depositAmount + betAmount;
    
    
    uint256 revealSpan = 10;
    bytes32 rand1 = "abc";
    bytes32 rand2 = "123";

    function commitmentRock(address sender) private view returns (bytes32) {
        return keccak256(abi.encodePacked(sender, RockPaperScissors.Choice.Rock, rand1));
    }
    function commitmentPaper(address sender) private view returns (bytes32) {
        return keccak256(abi.encodePacked(sender, RockPaperScissors.Choice.Paper, rand2));
    }
    
    function commitRevealAndDistribute (
        RpsProxy player0, RpsProxy player1,
        RockPaperScissors.Choice choice0, RockPaperScissors.Choice choice1, 
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

    function assertPlayersEqual(RockPaperScissors rps, RockPaperScissors.CommitChoice player0, RockPaperScissors.CommitChoice player1) private {
        address playerAddress0;
        bytes32 commitment0;
        RockPaperScissors.Choice choice0;
        bool receivedWinnings0;
        (playerAddress0, commitment0, choice0, receivedWinnings0) = rps.players(0);

        address playerAddress1;
        bytes32 commitment1;
        RockPaperScissors.Choice choice1;
        bool receivedWinnings1;
        (playerAddress1, commitment1, choice1, receivedWinnings1) = rps.players(1);

        Assert.equal(playerAddress0, player0.playerAddress, "Player 0 address does not equal supplied one.");
        Assert.equal(uint(choice0), uint(player0.choice), "Player 0 choice does not equal supplied one.");
        Assert.equal(commitment0, player0.commitment, "Player 0 commitment does not equal supplied one.");
        Assert.equal(receivedWinnings0, player0.receivedWinnings, "Player 0 received winnings does not equal supplied one.");

        Assert.equal(playerAddress1, player1.playerAddress, "Player 1 address does not equal supplied one.");
        Assert.equal(uint(choice1), uint(player1.choice), "Player 1 choice does not equal supplied one.");
        Assert.equal(commitment1, player1.commitment, "Player 1 commitment does not equal supplied one.");
        Assert.equal(receivedWinnings1, player1.receivedWinnings, "Player 1 received winnings does not equal supplied one.");
    }

    function assertPlayersEmpty(RockPaperScissors rps) private {
        RockPaperScissors.CommitChoice memory player0 = RockPaperScissors.CommitChoice(0, 0, RockPaperScissors.Choice.None, false);
        RockPaperScissors.CommitChoice memory  player1 = RockPaperScissors.CommitChoice(0, 0, RockPaperScissors.Choice.None, false);
        assertPlayersEqual(rps, player0, player1);
    }

    function assertStateEmptied(RockPaperScissors rps) private {
        // if all received the correct balance the contract should have been reset.
        Assert.equal(rps.revealDeadline(), 0, "Reveal deadline not reset to 0");
        Assert.equal(uint(rps.stage()), uint(RockPaperScissors.Stage.Commit), "Stage not reset to 'commit'.");
        Assert.equal(rps.commitPlayer(), 0, "Commit player not reset to 0.");
        assertPlayersEmpty(rps);
    }

    // paper vs rock
    function testDistributePaperBeatsRockPlayer0() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Paper, RockPaperScissors.Choice.Rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    function testDistributePaperBeatsRockPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Rock, RockPaperScissors.Choice.Paper, rand1, rand2);

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
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Scissors, RockPaperScissors.Choice.Paper, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    function testDistributeScissorsBeatsPaperPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Paper, RockPaperScissors.Choice.Scissors, rand1, rand2);

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
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Rock, RockPaperScissors.Choice.Scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
        assertStateEmptied(rps);
    }

    function testDistributeRockBeatsScissorsPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Scissors, RockPaperScissors.Choice.Rock, rand1, rand2);

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
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Rock, RockPaperScissors.Choice.Rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
        assertStateEmptied(rps);
    }

    function testDistributePaperDrawsWithPaper() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Paper, RockPaperScissors.Choice.Paper, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
        assertStateEmptied(rps);
    }

    function testDistributeScissorsDrawsWithScissors() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Scissors, RockPaperScissors.Choice.Scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
        assertStateEmptied(rps);
    }

    // TODO: test that anyone can call distribute

    function testDistributeMultipleCallsAreExceptedButDoNothing() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        ExecutionProxy player2 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, RockPaperScissors.Choice.Scissors, RockPaperScissors.Choice.Scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
        assertStateEmptied(rps);

        RockPaperScissors(player2).distribute();
        bool result = player2.execute();

        Assert.isFalse(result, "Additional calls to a successfull distribute should have failed.");
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not still have commit amount after second distribute.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not still have commit amount after second distribute.");
        assertStateEmptied(rps);
    }
}