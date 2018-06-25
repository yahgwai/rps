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

    function() payable public {
        emit Fallback(msg.sender, msg.data, msg.value);
        data = msg.data;
        value = msg.value;
    }

    function execute() public returns (bool) {
        return target.call.value(value)(data);
    }
}

contract RpsProxy {
    RockPaperScissors public rps;

    constructor(RockPaperScissors _rps){
        rps = _rps;
    }

    function commit(bytes32 commitment) payable public {
        this.rps().commit.value(msg.value)(commitment);
    }
}

contract TestRockPaperScissors {


    // struct CommitReveal {
    //     bytes32 commitment;
    //     uint8 reveal;
    // }

    uint256 public initialBalance = 10 ether;
    uint256 commitAmount = 100;
    uint256 commitAmountGreater = 150;
    uint8 rock = 1;
    uint8 paper = 2;
    uint8 scissors = 3;
    bytes32 rand1 = "abc";
    bytes32 rand2 = "123";

    bytes32 commitmentRock = keccak256(abi.encodePacked(rock, rand1));
    bytes32 commitmentPaper = keccak256(abi.encodePacked(paper, rand2));
    
    // we need to be able to receive ether as the RPS may send some back
    function() public payable {}

    // constructor
    //////////////////////////////////////////////////////////////////////

    function testConstructorSetbalance() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        
        Assert.equal(rps.bet(), commitAmount, "Contract bet amount does not equal supplied bet amount.");
    }

    // commit
    //////////////////////////////////////////////////////////////////////
    
    function testCommitIncreasesBalance() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        uint256 balanceBefore = address(rps).balance;
        rps.commit.value(commitAmount)(commitmentRock);
        uint256 balanceAfter = address(rps).balance;

        Assert.equal(balanceAfter - balanceBefore, commitAmount, "Balance not increased by commit amount.");
        Assert.equal(address(this).balance, 1 ether - commitAmount, "Sender acount did not decrease by bet amount.");
    }

    function testCommitIncreasesBalanceOnlyByBetAmount() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        // we need the rps proxy as the execution proxy already implements the 
        // fallback function with storage. Storage would cost too much gas than
        // that supplied in transfer so we would error here with that fallback.
        RpsProxy proxy = new RpsProxy(rps);
        uint256 balanceBefore = address(rps).balance;
        proxy.commit.value(commitAmount)(commitmentRock);
        uint256 balanceAfter = address(rps).balance;

        Assert.equal(balanceAfter - balanceBefore, commitAmount, "Balance not increased by commit amount when greater commit supplied.");
        // TODO: why does the line below send back to 'this'?
        //Assert.equal(address(proxy).balance, commitAmountGreater - commitAmount, "Sender account did not receive excess.");
    }

    function testCommitReturnsAllWhenCallingFallbackErrors() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        
        rps.commit.value(commitAmount)(commitmentRock);
        RockPaperScissors(executionProxy).commit.value(commitAmountGreater)(commitmentPaper);
        bool result = executionProxy.execute();

        Assert.isFalse(result, "Commit did not fail when fallback implemented with failure on commit call greater than bet.");
        Assert.equal(address(executionProxy).balance, commitAmountGreater, "Caller was not fully refunded when fallback function fails.");
    }


    function testCommitStoresSenderAndCommitmentHashedWithSender() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        rps.commit.value(commitAmount)(commitmentRock);
        bytes32 commitment;
        uint8 choice;
        (commitment, choice) = rps.players(this); 
        Assert.equal(commitment, keccak256(abi.encodePacked(this, commitmentRock)), "Commitment not stored against sender address.");
    }

    function testCommitStoresMultipleSendersAndCommitments() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        
        rps.commit.value(commitAmount)(commitmentRock);
        RockPaperScissors(executionProxy).commit.value(commitAmount)(commitmentPaper);
        bool result = executionProxy.execute();

        bytes32 commitment1;
        uint8 choice1;
        (commitment1, choice1) = rps.players(this); 

        bytes32 commitment2;
        uint8 choice2;
        (commitment2, choice2) = rps.players(executionProxy); 

        Assert.isTrue(result, "Execution proxy commit did not succeed.");
        Assert.notEqual(address(executionProxy), address(this), "Execution proxy address is the same as 'this' address");
        Assert.equal(commitment1, keccak256(abi.encodePacked(this, commitmentRock)), "Commit does not store first commitment.");
        Assert.equal(commitment2, keccak256(abi.encodePacked(executionProxy, commitmentPaper)), "Commit does not store second commitment.");
        Assert.equal(address(rps).balance, commitAmount * 2, "Stored value not equal to twice the commit amount.");
    }

    function testCommitRequiresNoMoreThanTwoSenders() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        rps.commit.value(commitAmount)(commitmentRock);
        rps.commit.value(commitAmount)(commitmentRock);
        
        // TODO: make sure the execution proxy is refunded
        RockPaperScissors(executionProxy).commit.value(commitAmount)(commitmentPaper);
        bool result = executionProxy.execute();

        Assert.isFalse(result, "Third commit did not throw.");
        Assert.equal(address(executionProxy).balance, commitAmount, "Not all of balance returned after fault.");
    }

    function testCommitRequiresSenderBetGreaterThanOrEqualContractBet() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);

        RockPaperScissors(executionProxy).commit.value(commitAmount - 1)(commitmentPaper);
        bool result = executionProxy.execute();

        Assert.isFalse(result, "Commit amount less than contact bet amount did not throw.");
        Assert.equal(address(executionProxy).balance, commitAmount - 1, "Not all of balance returned after fault.");
    }
    
    // reveal
    //////////////////////////////////////////////////////////////////////
    function commitPlayers(RockPaperScissors rps, bytes32 commitment1, bytes32 commitment2) public 
        returns(ExecutionProxy player1, ExecutionProxy player2) {
        player1 = new ExecutionProxy(rps);
        player2 = new ExecutionProxy(rps);
        RockPaperScissors(player1).commit.value(commitAmount)(commitment1);
        RockPaperScissors(player2).commit.value(commitAmount)(commitment2);
        player1.execute();
        player2.execute();

        return (player1, player2);
    }

    function testReveal() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps, commitmentRock, commitmentPaper);

        RockPaperScissors(player1).reveal(rock, rand1);
        bool result1 = player1.execute();

        bytes32 commitment1;
        uint8 choice1;
        (commitment1, choice1) = rps.players(player1);

        Assert.isTrue(result1, "Could not reveal player 1 rock.");
        Assert.equal(uint256(choice1), uint256(rock), "Player 1 did not have rock revealed as choice.");

        RockPaperScissors(player2).reveal(paper, rand2);
        bool result2 = player2.execute();

        bytes32 commitment2;
        uint8 choice2;
        (commitment2, choice2) = rps.players(player2);

        Assert.isTrue(result2, "Could not reveal player 2 paper.");
        Assert.equal(uint(choice2), uint(paper), "Player 2 did not have paper revealed as choice.");
    }

    //TODO: maybe also consider checking that player 1 had nothing untoward occur to them

    function testRevealRevertsUnknownSender() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps, commitmentRock, commitmentPaper);

        ExecutionProxy nonPlayer = new ExecutionProxy(rps);
        RockPaperScissors(nonPlayer).reveal(rock, rand1);
        bool result = nonPlayer.execute();

        Assert.isFalse(result, "Non player was allowed to reveal");
    }

    // TODO: should we revert this? or should it just not matter since these are not in the matrix 
    function testRevealRevertsInvalidUpperChoice() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps, keccak256(abi.encodePacked(uint8(4), rand1)), commitmentPaper);

        RockPaperScissors(player1).reveal(4, rand1);
        bool result1 = player1.execute();

        Assert.isFalse(result1, "Player allowed to reveal '4' as choice.");
    }

    function testRevealRevertsInvalidLowerChoice() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps, keccak256(abi.encodePacked(uint8(0), rand1)), commitmentPaper);

        RockPaperScissors(player1).reveal(0, rand1);
        bool result1 = player1.execute();

        Assert.isFalse(result1, "Player allowed to reveal '0' as choice.");
    }


    function testRevealRevertsInvalidChoiceRandPairing() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps, commitmentRock, commitmentPaper);

        RockPaperScissors(player1).reveal(rock, rand2);
        bool result1 = player1.execute();
        Assert.isFalse(result1, "Player allowed to reveal choice with wrong blind.");
        bytes32 commitment1;
        uint8 choice1;
        (commitment1, choice1) = rps.players(player1);
        Assert.equal(uint(choice1), uint(0), "Choice no longer set to zero for wrong blind.");

        RockPaperScissors(player1).reveal(paper, rand1);
        bool result2 = player1.execute();
        Assert.isFalse(result2, "Player allowed to reveal wrong choice with correct blind.");
        bytes32 commitment2;
        uint8 choice2;
        (commitment2, choice2) = rps.players(player2);
        Assert.equal(uint(choice2), uint(0), "Choice no longer set to zero for wrong choice.");
        

        RockPaperScissors(player1).reveal(rock, rand1);
        bool result3 = player1.execute();
        Assert.isTrue(result3, "Player not allowed to reveal correct choice with correct blind.");
        bytes32 commitment3;
        uint8 choice3;
        (commitment3, choice3) = rps.players(player1);
        Assert.equal(uint(choice3), uint(rock), "Choice not correctly updated to 'rock'.");
    }

    function testProxyReveal() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy proxy = new ExecutionProxy(rps);
        RockPaperScissors(proxy).reveal(rock, rand1);
        
        bool result1 = proxy.execute();
        Assert.isFalse(result1, "Player 2 allowed to reveal player 1.");
    }
    
    function testPlayerCannotRevealOtherPlayer() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy player1;
        ExecutionProxy player2;
        (player1, player2) = commitPlayers(rps, commitmentRock, commitmentPaper);
        
        RockPaperScissors(player2).reveal(rock, rand1);
        bool result1 = player2.execute();
        Assert.isFalse(result1, "Player 2 allowed to reveal player 1.");
        bytes32 commitment;
        uint8 choice;
        (commitment, choice) = rps.players(player1);
        Assert.equal(uint(choice), uint(0), "player 2 allowed to update choice of player 1.");
    }




    //TODO: do we need to include the sender in the hash? why did they do it in the paper?
}