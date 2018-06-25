pragma solidity ^0.4.2;

// ISSUES

// 1. Player cannot currently avoid having their game hijacked by a 3rd party
// 2. Tests are all made from a single account, when really we should be testing from multiple accounts


contract RockPaperScissors {
    uint8 constant rock = 1;
    uint8 constant paper = 2;
    uint8 constant scissors = 3;

    struct CommitChoice {
        bytes32 commitment;
        uint8 choice;        
    }

    uint256 public bet;
    mapping(address => CommitChoice) public players;    
    uint256 totalCommitments = 0;
    // TODO: look at all the access modifiers for all members and functions
    // TODO: what are the consequences?

    event ReceiveAmount(uint256 amount);

    constructor(uint256 betAmount) public {
        bet = betAmount;
    }
    
    // commit-reveal contract for playing rock paper scissors
    
    // commit a hash of your choice+random number
    
    // when both choices have been supplied, reveal by supplying a the choice+rand
    // call to finalise to distribute the funds

    // additional features:
    // both players must reveal with a timeout,
    // finalise cannot be called within this timeout? no, can be called whenever we have enough reveals
    // if player does not reveal they loose a deposit

    // no re-entrancy
    // no stack overflow resulting in uneven distribution
    // should bet the same amount? no, allow any amount.

    // TODO: go through and write explicit 'stored' and 'memory' everywhere
    function commit(bytes32 commitment) payable public {
        require(msg.value >= bet);
        require(totalCommitments < 2);
        // return any excess
        if(msg.value > bet) {
            msg.sender.transfer(msg.value - bet);
        }

        //ensure that only this sender can reveal this commitment
        bytes32 hashedCommitment = keccak256(abi.encodePacked(msg.sender, commitment));
        // store the commitment, and the record of the commitment        
        players[msg.sender] = CommitChoice(hashedCommitment, 0);
        totalCommitments = totalCommitments + 1;
    }

    event Reveal(address sender, uint8 choice, bytes32 blind);

    function reveal(uint8 choice, bytes32 blindingFactor) public {
        emit Reveal(msg.sender, choice, blindingFactor);
        require(choice == rock || choice == paper || choice == scissors);
        CommitChoice storage commitChoice = players[msg.sender]; 
        //check the hash
        require(keccak256(abi.encodePacked(msg.sender, abi.encodePacked(choice, blindingFactor))) == commitChoice.commitment);
        // update if correct
        commitChoice.choice = choice;
    }

    function distribute() public {

    }

    // concerns - assymetry in setting timeout
    // concerns - timeout not greatly reduced by addition deposit
}

