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

contract Test_RockPaperScissors_Commit {
    uint256 public initialBalance = 10 ether;
    uint256 commitAmount = 100;
    uint256 commitAmountGreater = 150;
    uint256 depositAmount = 25;
    uint256 revealSpan = 10;

    // TODO: test greater deposit amounts

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
    
    function testCommitIncreasesBalance() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        uint256 balanceBefore = address(rps).balance;
        rps.commit.value(commitAmount)(commitmentRock(this));
        uint256 balanceAfter = address(rps).balance;

        Assert.equal(balanceAfter - balanceBefore, commitAmount, "Balance not increased by commit amount.");
        Assert.equal(address(this).balance, initialBalance - commitAmount, "Sender acount did not decrease by bet amount.");
    }

    function testCommitIncreasesBalanceOnlyByBetAmount() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        // we need the rps proxy as the execution proxy already implements the 
        // fallback function with storage. Storage would cost too much gas than
        // that supplied in transfer so we would error here with that fallback.
        RpsProxy proxy = new RpsProxy(rps);
        uint256 balanceBefore = address(rps).balance;
        proxy.commit.value(commitAmount)(commitmentRock(proxy));
        uint256 balanceAfter = address(rps).balance;

        Assert.equal(balanceAfter - balanceBefore, commitAmount, "Balance not increased by commit amount when greater commit supplied.");
        // TODO: why does the line below send back to 'this'?
        //Assert.equal(address(proxy).balance, commitAmountGreater - commitAmount, "Sender account did not receive excess.");
    }

    function testCommitReturnsAllWhenCallingFallbackErrors() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        
        rps.commit.value(commitAmount)(commitmentRock(executionProxy));
        RockPaperScissors(executionProxy).commit.value(commitAmountGreater)(commitmentPaper(executionProxy));
        bool result = executionProxy.execute();

        Assert.isFalse(result, "Commit did not fail when fallback implemented with failure on commit call greater than bet.");
        Assert.equal(address(executionProxy).balance, commitAmountGreater, "Caller was not fully refunded when fallback function fails.");
    }


    function testCommitStoresSenderAndCommitmentHashedWithSender() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        rps.commit.value(commitAmount)(commitmentRock(this));
        bytes32 commitment;
        uint8 choice;
        address playerAddress;
        (playerAddress, commitment, choice) = rps.players(0); 
        Assert.equal(commitment, commitmentRock(this), "Commitment not stored against sender address.");
    }

    function testCommitStoresMultipleSendersAndCommitments() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        
        rps.commit.value(commitAmount)(commitmentRock(this));
        RockPaperScissors(executionProxy).commit.value(commitAmount)(commitmentPaper(executionProxy));
        bool result = executionProxy.execute();

        bytes32 commitment1;
        uint8 choice1;
        address playerAddress1;
        (playerAddress1, commitment1, choice1) = rps.players(0); 

        bytes32 commitment2;
        uint8 choice2;
        address playerAddress2;
        (playerAddress2, commitment2, choice2) = rps.players(1); 

        Assert.isTrue(result, "Execution proxy commit did not succeed.");

        Assert.notEqual(address(executionProxy), address(this), "Execution proxy address is the same as 'this' address");
        Assert.equal(commitment1, commitmentRock(this), "Commit does not store first commitment.");
        Assert.equal(commitment2, commitmentPaper(executionProxy), "Commit does not store second commitment.");
        Assert.equal(address(rps).balance, commitAmount * 2, "Stored value not equal to twice the commit amount.");
    }

    function testCommitRequiresNoMoreThanTwoSenders() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        rps.commit.value(commitAmount)(commitmentRock(this));
        rps.commit.value(commitAmount)(commitmentRock(this));
        
        // TODO: make sure the execution proxy is refunded
        RockPaperScissors(executionProxy).commit.value(commitAmount)(commitmentPaper(executionProxy));
        bool result = executionProxy.execute();

        Assert.isFalse(result, "Third commit did not throw.");
        Assert.equal(address(executionProxy).balance, commitAmount, "Not all of balance returned after fault.");
    }

    function testCommitRequiresSenderBetGreaterThanOrEqualContractBet() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount, depositAmount, revealSpan);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);

        RockPaperScissors(executionProxy).commit.value(commitAmount - 1)(commitmentPaper(executionProxy));
        bool result = executionProxy.execute();

        Assert.isFalse(result, "Commit amount less than contact bet amount did not throw.");
        Assert.equal(address(executionProxy).balance, commitAmount - 1, "Not all of balance returned after fault.");
    }
}