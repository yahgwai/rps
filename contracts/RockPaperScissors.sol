pragma solidity ^0.4.2;

// ISSUES

// 1. Player cannot currently avoid having their game hijacked by a 3rd party, 
//      they can do this by jumping in straight after another player commits, then revealing to start the timout
//      after the reveal the user must play
// 2. By setting the deadline in the reveal we give the players the option to
//      withdraw before one reveals - this shouldnt be allowed, it should be moved into the commit

// concerns - assymetry in setting timeout
    // concerns - timeout not greatly reduced by addition deposit

// TODO: look at all the access modifiers for all members and functions
// TODO: what are the consequences?

// TODO: checkout all the integer operations for possible overflows

// TODO:
// check no re-entrancy
// check no stack overflow results in uneven distribution


// IMPROVMENTS:

// 1. Allow second player to reveal without committing.
// 2. Allow re-use of the contract? Or allow a self destruct to occur?
// 3. Choose where to send lost deposits.

contract RockPaperScissors {
    uint8 constant rock = 0x1;
    uint8 constant paper = 0x2;
    uint8 constant scissors = 0x3;
    struct CommitChoice {
        address playerAddress;
        bytes32 commitment;
        uint8 choice;        
    }

    //TODO: decide whether to keep deposits in the state.
    // payout[0] - burn player 0 deposit
    // payout[1] - pay player 0 deposit
    // payout[2] - pay player 0 back their bet
    // payout[3] - pay player 0 the bet by player 1
    // payout[4] - burn player 1 deposit
    // payout[5] - pay player 1 deposit
    // payout[6] - pay player 1 back their bet
    // payout[7] - pay player 1 the bet by player 0

    // draw             01100110    0x66
    // p0win            01110100    0x74
    // p1win            01000111    0x47
    // p0winp1forfeit   01111000    0x78
    // p1winp0forfeit   10000111    0x87

    uint8[4][4] winMatrix = [
        [ 0x66, 0x87, 0x87, 0x87 ],
        [ 0x78, 0x66, 0x74, 0x47 ],
        [ 0x78, 0x47, 0x66, 0x74 ],
        [ 0x78, 0x74, 0x47, 0x66 ]
    ];

    //initialisation args
    uint256 public bet;
    uint256 public deposit;
    uint256 public revealSpan;

    // state args
    CommitChoice[2] public players;
    uint256 public revealDeadline;
    uint8 public distributedWinnings;

    constructor(uint256 _bet, uint256 _deposit, uint256 _revealSpan) public {
        bet = _bet;
        deposit = _deposit;
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
        if(msg.value > commitAmount) msg.sender.transfer(msg.value - commitAmount);

        // choose the player
        uint8 playerIndex = players[0].commitment == bytes32(0x0) ? 0 : 1;
        
        // store the commitment, and the record of the commitment        
        players[playerIndex] = CommitChoice(msg.sender, commitment, 0);
    }

    function reveal(uint8 choice, bytes32 blindingFactor) public {
        // valid choices
        require(choice == rock || choice == paper || choice == scissors);
        
        // find the player index
        uint8 playerIndex;
        if(players[0].playerAddress == msg.sender) playerIndex = 0;
        else if (players[1].playerAddress == msg.sender) playerIndex = 1;
        // unknown player
        else revert();

        // find the player data
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

    function distribute() public {
        // to distribute we need:
        // a) to be past the deadline OR b) both players have revealed
        require(revealDeadline < block.number || (players[0].choice != 0 && players[1].choice != 0));        

        // find the payout
        uint8 payout = winMatrix[players[1].choice][players[0].choice];

        // remove any existing payouts
        uint8 remainingPayout = payout ^ distributedWinnings;

        // calulate value of payouts for players
        //TODO: possible overflow
        uint256 player0Payout = getBit(remainingPayout, 1) * deposit + getBit(remainingPayout, 2) * bet + getBit(remainingPayout, 3) * bet;
        uint256 player1Payout = getBit(remainingPayout, 5) * deposit + getBit(remainingPayout, 6) * bet + getBit(remainingPayout, 7) * bet;

        // send the payouts
        bool player0Success = players[0].playerAddress.send(player0Payout);
        bool player1Success = players[1].playerAddress.send(player1Payout);

        // mask the player0 payouts and add them to any existing records
        if(player0Success == true) distributedWinnings = distributedWinnings | (payout & 0xF0);
        if(player1Success == true) distributedWinnings = distributedWinnings | (payout & 0x0F);

        // if we have distributed the full payout, then lets zero the state
        //TODO: this won't work unless we update distributed winnings to a take into account the deposit bits
        if((remainingPayout ^ distributedWinnings) == 0) {
            revealDeadline = 0;
            distributedWinnings = 0;
            delete players;            
        }
    }

    function getBit(uint8 bits, uint8 index) pure private returns(uint8) {
        // TODO: fudges
        //return (bits & 2 ** index) / (2  ** index);
        return uint8(bits >> (7 - index) & 1);
        //return (uint8((bits << index) & uint8(128))) / 128;
    }
}

