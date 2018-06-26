pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RockPaperScissors.sol";
import "./ExecutionProxy.sol";

contract Test_RockPaperScissors_Distribute {
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

    function commitmentRock(address sender) private returns (bytes32) {
        return keccak256(abi.encodePacked(sender, rock, rand1));
    }
    function commitmentPaper(address sender) private returns (bytes32) {
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

    function commitRevealAndDistribute(
        ExecutionProxy player0, ExecutionProxy player1,
        uint8 choice0, uint8 choice1, 
        bytes32 blind0, bytes32 blind1) public {

        //commit
        RockPaperScissors(player0).commit.value(commitAmount)(keccak256(abi.encodePacked(player0, choice0, blind0)));
        RockPaperScissors(player1).commit.value(commitAmount)(keccak256(abi.encodePacked(player1, choice1, blind1)));
        player0.execute();
        player1.execute();

        //reveal
        RockPaperScissors(player0).reveal(choice0, blind0);
        RockPaperScissors(player1).reveal(choice1, blind1);
        player0.execute();
        player1.execute();

        //distribute
        RockPaperScissors(player0).distribute();
        player0.execute();
    }

    // paper vs rock
    function testDistributePaperBeatsRockPlayer0() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, paper, rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
    }

    function testDistributePaperBeatsRockPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, paper, rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player0).balance, depositAmount, "Player 1 did not only receive back deposit.");
    }

    // scissors vs paper
    function testDistributeScissorsBeatsPaperPlayer0() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, scissors, paper, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
    }

    function testDistributeScissorsBeatsPaperPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, paper, scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player0).balance, depositAmount, "Player 1 did not only receive back deposit.");
    }

    // rock vs scissors
    function testDistributeRockBeatsScissorsPlayer0() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, rock, scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player0).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player1).balance, depositAmount, "Player 1 did not only receive back deposit.");
    }

    function testDistributeRockBeatsScissorsPlayer1() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, scissors, rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, depositAmount + (2 * betAmount), "Player 0 did not receive winnings + deposit.");
        Assert.equal(address(player0).balance, depositAmount, "Player 1 did not only receive back deposit.");
    }

    // draws
    function testDistributeRockDrawsWithRock() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, rock, rock, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
    }

    function testDistributePaperDrawsWithPaper() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, paper, paper, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
    }

    function testDistributeScissorsDrawsWithScissors() public {
        RockPaperScissors rps = new RockPaperScissors(betAmount, depositAmount, revealSpan);
        ExecutionProxy player0 = new ExecutionProxy(rps);
        ExecutionProxy player1 = new ExecutionProxy(rps);
        commitRevealAndDistribute(player0, player1, scissors, scissors, rand1, rand2);

        //check the balance of player 0 and player 1
        Assert.equal(address(player1).balance, commitAmount, "Player 0 did not receive back commit amount.");
        Assert.equal(address(player0).balance, commitAmount, "Player 1 did not receive back commit amount.");
    }

    // function testDistributeRockDrawsWithRock() public {}
    // function testDistributePaperDrawsWithPaper() public {}
    // function testDistributeScissorsDrawWithScissors() public {}
    // function testDistributeOnlyOneChoiceRevealedWinsAfterRevealDeadlineReached() public {}
    // function testDistributeNoRevealsIsADraw() public {}
    // function testDistributeRevertsWhenContractCantReceiveWinnings() public {}
    // function testDistributeBurnsDepositIfSettleBlockIsReached() public {}
    // function testDistributeWillAlwaysSettleWithTwoReveals() public {}
    // function testDistributeWillNotSettleWhenLessThanTwoRevealsAndSettleBlockReached() public {}
    // function testDistributeWillRevertIfDepositDistributionFails() public {}
    // function testDistributeDepositAndWinningsDistributionCannotBeBlockedByRevertDuringDistributionToOtherParty() public {}
    // function testDistributeResetsAllCountersAfterSuccess() public {}
    // function testDistributeMultipleCallsDoNothing() public {}
    
    // function testFullFlowCanOccurWithoutdeposit() public {}




    //TODO: do we need to include the sender in the hash? why did they do it in the paper?
}