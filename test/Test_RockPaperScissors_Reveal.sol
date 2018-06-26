pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RockPaperScissors.sol";

// adapted from https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests
contract ExecutionProxy {
    address public target;
    bytes data;
    uint256 value;

    constructor(address _target) public {
        target = _target;
    }

    event Fallback(address sender, bytes data, uint256 value);
    event FallbackSetData(bytes data, uint256 value);

    function() payable public {
        emit Fallback(msg.sender, msg.data, msg.value);
        data = msg.data;
        value = msg.value;
        emit FallbackSetData(data, value);
    }

    function execute() public returns (bool) {
        return target.call.value(value)(data);
    }
}

contract RpsProxy {
    RockPaperScissors public rps;

    constructor(RockPaperScissors _rps) public {
        rps = _rps;
    }

    function commit(bytes32 commitment) payable public {
        this.rps().commit.value(msg.value)(commitment);
    }
}

contract Test_RockPaperScissors_Reveal {
    uint256 public initialBalance = 10 ether;
    uint256 commitAmount = 100;
    uint256 commitAmountGreater = 150;
    uint256 depositAmount = 25;
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
    
    function commitPlayers(RockPaperScissors rps) public 
        returns(ExecutionProxy player1, ExecutionProxy player2) {
        player1 = new ExecutionProxy(rps);
        player2 = new ExecutionProxy(rps);
        RockPaperScissors(player1).commit.value(commitAmount)(commitmentRock(player1));
        RockPaperScissors(player2).commit.value(commitAmount)(commitmentPaper(player2));
        player1.execute();
        player2.execute();

        return (player1, player2);
    }

    // TODO: test that commit correctly sets the address

    function testReveal() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps);

        RockPaperScissors(player1).reveal(rock, rand1);
        bool result1 = player1.execute();

        bytes32 commitment1;
        uint8 choice1;
        address playerAddress1;
        (playerAddress1, commitment1, choice1) = rps.players(0);

        Assert.isTrue(result1, "Could not reveal player 1 rock.");
        Assert.equal(uint256(choice1), uint256(rock), "Player 1 did not have rock revealed as choice.");

        RockPaperScissors(player2).reveal(paper, rand2);
        bool result2 = player2.execute();

        bytes32 commitment2;
        uint8 choice2;
        address playerAddress2;
        (playerAddress2, commitment2, choice2) = rps.players(1);

        Assert.isTrue(result2, "Could not reveal player 2 paper.");
        Assert.equal(uint(choice2), uint(paper), "Player 2 did not have paper revealed as choice.");
    }

    //TODO: maybe also consider checking that player 1 had nothing untoward occur to them

    function testRevealRevertsUnknownSender() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps);

        ExecutionProxy nonPlayer = new ExecutionProxy(rps);
        RockPaperScissors(nonPlayer).reveal(rock, rand1);
        bool result = nonPlayer.execute();

        Assert.isFalse(result, "Non player was allowed to reveal");
    }

    // TODO: should we revert this? or should it just not matter since these are not in the matrix 
    function testRevealRevertsInvalidUpperChoice() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps);
        //TODO:
        //, keccak256(abi.encodePacked(uint8(4), rand1)), commitmentPaper);

        RockPaperScissors(player1).reveal(4, rand1);
        bool result1 = player1.execute();

        Assert.isFalse(result1, "Player allowed to reveal '4' as choice.");
    }

    function testRevealRevertsInvalidLowerChoice() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps);
        //TODO:
        // , keccak256(abi.encodePacked(uint8(0), rand1)), commitmentPaper);

        RockPaperScissors(player1).reveal(0, rand1);
        bool result1 = player1.execute();

        Assert.isFalse(result1, "Player allowed to reveal '0' as choice.");
    }


    // //TODO: test that addresses have not changed

    function testRevealPlayerCannotRevealOtherPlayer() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps);
        
        RockPaperScissors(player2).reveal(rock, rand1);
        bool result1 = player2.execute();
        Assert.isFalse(result1, "Player 2 allowed to reveal player 1.");
        bytes32 commitment;
        uint8 choice;
        address playerAddress;
        (playerAddress, commitment, choice) = rps.players(0);
        Assert.equal(uint(choice), uint(0), "player 2 allowed to update choice of player 1.");
    }

    // function testConstructorSetsRevealDeadlineSpan() public {}
    // function testConstructorSetsDepositAmount() public {}

    // function testCommitTestStoresDeposit() public {}

    // function testRevealSuccessfulFirstRevealSetsRevealDeadline() public {}
    // function testRevealSubsequentRevealsDoNotAdjustRevealDeadline() public {}
    // function testRevealCanStillBeSuccessfullyCalledAfterDeadline() public {}
    // function testRevealCannotBeCalledAfterDistribute() public {}

    // function testDistributePaperBeatsRock() public {}
    // function testDistributeRockBeatsScissors() public {}
    // function testDistributeScissorsBeatsPaper() public {}
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

    // function testFullFlowCanOccurWithoutdeposit() public {}




    //TODO: do we need to include the sender in the hash? why did they do it in the paper?
}