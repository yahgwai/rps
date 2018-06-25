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

    function() payable public {
        data = msg.data;
        value = msg.value;
    }

    function execute() public returns (bool) {
        return target.call.value(value)(data);
    }
}

contract ThrowingCaller {
    RockPaperScissors rps;

    constructor(RockPaperScissors _rps){
        rps = _rps;
    }

    function commitRps(bytes32 commitment) public {
        rps.commit.value(msg,value)(commitment);
    }

    function() public payable {
        revert();
    }
}

contract TestRockPaperScissors {
    uint256 public initialBalance = 1 ether;
    uint256 commitAmount = 100;
    uint256 commitAmountGreater = 150;
    bytes32 commitmentRock = keccak256(abi.encodePacked("rock", "abc"));
    bytes32 commitmentPaper = keccak256(abi.encodePacked("paper", "123"));
    
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
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        RockPaperScissors(executionProxy).commit.value(commitAmountGreater)(commitmentPaper);
        
        uint256 balanceBefore = address(rps).balance;
        bool result = executionProxy.execute();
        uint256 balanceAfter = address(rps).balance;

        Assert.equal(balanceAfter - balanceBefore, commitAmount, "Balance not increased by commit amount when greater commit supplied.");
        Assert.equal(address(executionProxy).balance, commitAmountGreater - commitAmount, "Sender account did not receive excess.");
    }

    function testCommitStoresSenderAndCommitment() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        rps.commit.value(commitAmount)(commitmentRock);
        Assert.equal(rps.commitments(this), commitmentRock, "Commitment not stored against sender address.");
    }

    function testCommitStoresMultipleSendersAndCommitments() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);
        
        rps.commit.value(commitAmount)(commitmentRock);
        RockPaperScissors(executionProxy).commit.value(commitAmount)(commitmentPaper);
        bool result = executionProxy.execute();

        Assert.isTrue(result, "Execution proxy commit did not succeed.");
        Assert.notEqual(address(executionProxy), address(this), "Execution proxy address is the same as 'this' address");
        Assert.equal(rps.commitments(this), commitmentRock, "Commit does not store first commitment.");
        Assert.equal(rps.commitments(executionProxy), commitmentPaper, "Commit does not store second commitment.");
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
        Assert.isEqual(address(executionProxy).balance, commitAmount, "Not all of balance returned after fault.");
    }

    function testCommitRequiresSenderBetGreaterThanOrEqualContractBet() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        ExecutionProxy executionProxy = new ExecutionProxy(rps);

        RockPaperScissors(executionProxy).commit.value(commitAmount - 1)(commitmentPaper);
        bool result = executionProxy.execute();

        Assert.isFalse(result, "Commit amount less than contact bet amount did not throw.");
        Assert.isEqual(address(executionProxy).balance, commitAmount - 1, "Not all of balance returned after fault.");
    }
    
    // reveal
    //////////////////////////////////////////////////////////////////////


}