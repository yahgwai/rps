pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./ExecutionProxy.sol";
import "../contracts/RockPaperScissors.sol";
import "./RpsProxy.sol";

contract Test_RockPaperScissors_DistributeExtended {
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

    function commitReveal0NotReveal1AndDistribute (
        RpsProxy player0, RpsProxy player1,
        uint8 choice0, uint8 choice1, 
        bytes32 blind0, bytes32 blind1) public {

        //commit
        player0.commit.value(commitAmount)(keccak256(abi.encodePacked(player0, choice0, blind0)));
        player1.commit.value(commitAmount)(keccak256(abi.encodePacked(player1, choice1, blind1)));
        
        //reveal
        player0.reveal(choice0, blind0);

        //distribute
        player0.distribute();
    }

    function commitReveal1NotReveal0AndDistribute (
        RpsProxy player0, RpsProxy player1,
        uint8 choice0, uint8 choice1, 
        bytes32 blind0, bytes32 blind1) public {

        //commit
        player0.commit.value(commitAmount)(keccak256(abi.encodePacked(player0, choice0, blind0)));
        player1.commit.value(commitAmount)(keccak256(abi.encodePacked(player1, choice1, blind1)));
        
        //reveal
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
    
    function testDistributeOnlyPlayer0ChoiceRevealedWinsAfterRevealDeadlineReached() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, 0);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitReveal0NotReveal1AndDistribute(player0, player1, scissors, rock, rand1, rand2);

        // check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, betAmount * 2 + depositAmount, "Player 0 did not win.");
        Assert.equal(address(player1).balance, 0, "Player 1 did not loose all money.");
        
        assertStateEmptied(rps);
    }

    function testDistributeOnlyPlayer1ChoiceRevealedWinsAfterRevealDeadlineReached() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, 0);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);
        commitReveal1NotReveal0AndDistribute(player0, player1, scissors, rock, rand1, rand2);

        // check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, betAmount * 2 + depositAmount, "Player 1 did not win.");
        Assert.equal(address(player0).balance, 0, "Player 0 did not loose all money.");
        
        assertStateEmptied(rps);
    }

    function testDistributeOnlyPlayer0ChoiceRevealedNoOneWinsBeforeDeadline() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);

        //commit
        bytes32 commitment0 = keccak256(abi.encodePacked(player0, rock, rand1));
        bytes32 commitment1 = keccak256(abi.encodePacked(player1, paper, rand2));
        RockPaperScissors(player0).commit.value(commitAmount)(commitment0);
        player0.execute();
        player1.commit.value(commitAmount)(commitment1);

        //reveal
        RockPaperScissors(player0).reveal(rock, rand1);
        player0.execute();
        
        //distribute
        RockPaperScissors(player0).distribute();
        bool result = player0.execute();

        // check the balance of player 0 and player 1
        Assert.isFalse(result, "Distribute succeeded before deadline.");        
        assertPlayersEqual(rps, CommitChoice(player0, commitment0, rock), CommitChoice(player1, commitment1, 0));
    }

    function testDistributeOnlyPlayer1ChoiceRevealedNoOneWinsBeforeDeadline() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);

        //commit
        bytes32 commitment0 = keccak256(abi.encodePacked(player0, rock, rand1));
        bytes32 commitment1 = keccak256(abi.encodePacked(player1, paper, rand2));
        RockPaperScissors(player0).commit.value(commitAmount)(commitment0);
        player0.execute();
        player1.commit.value(commitAmount)(commitment1);

        //reveal
        player1.reveal(paper, rand2);
        
        //distribute
        RockPaperScissors(player0).distribute();
        bool result = player0.execute();

        // check the balance of player 0 and player 1
        Assert.isFalse(result, "Distribute succeeded before deadline.");        
        assertPlayersEqual(rps, CommitChoice(player0, commitment0, 0), CommitChoice(player1, commitment1, paper));
    }

    function testDistributeSendBackMoneyIfNoReveals() public {
        //TODO: we shouldnt have this pattern - reveal should not work and we should add the second user to the commit
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, 0);
        RpsProxy player0 = new RpsProxy(rps);
        RpsProxy player1 = new RpsProxy(rps);

        //commit
        player0.commit.value(commitAmount)(keccak256(abi.encodePacked(player0, rock, rand1)));
        player1.commit.value(commitAmount)(keccak256(abi.encodePacked(player1, paper, rand2)));
        
        //distribute
        player0.distribute();

        // check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, commitAmount, "Player 0 did not draw.");
        Assert.equal(address(player1).balance, commitAmount, "Player 1 did not draw.");
        assertPlayersEmpty(rps);
    }
}