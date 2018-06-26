pragma solidity ^0.4.2;

// ISSUES

// 1. Player cannot currently avoid having their game hijacked by a 3rd party
// 2. Tests are all made from a single account, when really we should be testing from multiple accounts


contract RockPaperScissors {
    uint8 constant rock = 0x01;
    uint8 constant paper = 0x02;
    uint8 constant scissors = 0x03;

    uint8 constant draw = 0x00;
    uint8 constant player1Wins = 0x01;
    uint8 constant player1WinsPlayer2Forfeits = 0x02;
    uint8 constant player2Wins = 0x03;
    uint8 constant player2WinsPlayer1Forfeits = 0x04;

    uint8[4][4] winMatrix = [
        [ draw, player2WinsPlayer1Forfeits, player2WinsPlayer1Forfeits, player2WinsPlayer1Forfeits ],
        [ player1WinsPlayer2Forfeits, draw, player1Wins, player2Wins],
        [ player1WinsPlayer2Forfeits, player2Wins, draw, player1Wins],
        [ player1WinsPlayer2Forfeits, player1Wins, player2Wins, draw]
    ];

    struct CommitChoice {
        address playerAddress;
        bytes32 commitment;
        uint8 choice;        
    }

    CommitChoice[2] public players;

    uint256 public bet;
    //mapping(address => CommitChoice) public players;    
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
        // player 1 has commited then 
        require(players[1].commitment == 0);
        // return any excess
        if(msg.value > bet) {
            msg.sender.transfer(msg.value - bet);
        }

        // ensure that only this sender can reveal this commitment
        bytes32 hashedCommitment = commitment;
        // choose the player
        uint8 playerIndex;
        if(players[0].commitment == 0) playerIndex = 0;
        else playerIndex = 1;
        
        // store the commitment, and the record of the commitment        
        players[playerIndex] = CommitChoice(msg.sender, hashedCommitment, 0);
    }

    function reveal(uint8 choice, bytes32 blindingFactor) public {
        require(choice == rock || choice == paper || choice == scissors);
        // find the player index
        uint8 playerIndex;
        if(players[0].playerAddress == msg.sender) playerIndex = 0;
        else if (players[1].playerAddress == msg.sender) playerIndex = 1;
        else revert();
        // find thir data
        CommitChoice storage commitChoice = players[playerIndex]; 
        // check the hash, we have a hash of sender, choice, blind so that players cannot learn anything from a committment
        // if it were just choice, blind the other player could view this an submit ti themselves to reliably achieve a draw
        require(keccak256(abi.encodePacked(msg.sender, choice, blindingFactor)) == commitChoice.commitment);
        // update if correct
        commitChoice.choice = choice;
    }

    function distribute() view public {
        
    }

    // concerns - assymetry in setting timeout
    // concerns - timeout not greatly reduced by addition deposit
}

