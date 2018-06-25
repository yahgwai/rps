pragma solidity ^0.4.2;

// ISSUES

// 1. Player cannot currently avoid having their game hijacked by a 3rd party
// 2. Tests are all made from a single account, when really we should be testing from multiple accounts


contract RockPaperScissors {
    uint256 public bet;
    mapping(address => bytes32) public commitments;
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

        // store the commitment
        addCommitment(commitment); 
    }

    /**
     * Add a commitment to the mapping.
     * Keeps a track of the number of the commitments in the mapping.
     */
    // TODO: make this a pure and public function, so that it can be tested.
    function addCommitment(bytes32 commitment) private {
        commitments[msg.sender] = commitment;
        totalCommitments = totalCommitments + 1;
    }

    function reveal(uint8 choice, bytes32 blind) public {

    }

    function distribute() public {

    }

    // concerns - assymetry in setting timeout
    // concerns - timeout not greatly reduced by addition deposit
}

