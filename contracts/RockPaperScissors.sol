pragma solidity ^0.4.2;

// ISSUES

// 1. Player cannot currently avoid having their game hijacked by a 3rd party, 
//      they can do this by jumping in straight after another player commits, then revealing to start the timout
//      after the reveal the user must play
// 2. By setting the deadline in the reveal we give the players the option to
//      withdraw before one reveals - this shouldnt be allowed, it should be moved into the commit


// IMPROVMENTS:

// 1. Allow second player to reveal without committing.

contract RockPaperScissors {
    uint8 constant rock = 0x1;
    uint8 constant paper = 0x2;
    uint8 constant scissors = 0x3;

    uint8 constant draw = 0x0;
    uint8 constant player1Wins = 0x1;
    uint8 constant player1WinsPlayer2Forfeits = 0x2;
    uint8 constant player2Wins = 0x3;
    uint8 constant player2WinsPlayer1Forfeits = 0x4;

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
    uint256 public deposit;
    uint256 public revealSpan;
    uint256 public revealDeadline;

    
    // TODO: look at all the access modifiers for all members and functions
    // TODO: what are the consequences?

    // TODO: checkout all the integer operations for possible overflows

    // TODO:
    // check no re-entrancy
    // check no stack overflow results in uneven distribution

    event ReceiveAmount(uint256 amount);

    constructor(uint256 _bet, uint256 _deposit, uint256 _revealSpan) public {
        bet = _bet;
        deposit = _deposit;
        // TODO: overflow
        revealSpan = _revealSpan;
    }

    // TODO: go through and write explicit 'stored' and 'memory' everywhere
    function commit(bytes32 commitment) payable public {
        //TODO: possible overflow
        uint256 commitAmount = bet + deposit;
        require(msg.value >= commitAmount);
        // if player 1 has commited then we allow no more commitment
        require(players[1].commitment == bytes32(0x0));
        // return any excess
        if(msg.value > commitAmount) {
            //TODO: possible overflow
            msg.sender.transfer(msg.value - commitAmount);
        }

        // choose the player
        uint8 playerIndex;
        if(players[0].commitment == bytes32(0x0)) playerIndex = 0;
        else playerIndex = 1;
        
        // store the commitment, and the record of the commitment        
        players[playerIndex] = CommitChoice(msg.sender, commitment, 0);
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
        // if this is the first reveal we set the deadline for the second one
        // TODO: possible overflow
        if(revealDeadline == 0) revealDeadline = block.number + revealSpan;
    }

    function distribute() view public {
        
    }

    // concerns - assymetry in setting timeout
    // concerns - timeout not greatly reduced by addition deposit
}

