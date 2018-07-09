pragma solidity ^0.4.24;

contract RockPaperScissors {
    enum Choice {
        None,
        Rock,
        Paper,
        Scissors
    }

    enum Stage {
        FirstCommit,
        SecondCommit,
        FirstReveal,
        SecondReveal,
        Distribute
    }

    struct CommitChoice {
        address playerAddress;
        bytes32 commitment;
        Choice choice;
    }

    //initialisation args
    uint public bet;
    uint public deposit;
    uint public revealSpan;

    // state vars
    CommitChoice[2] public players;
    uint public revealDeadline;
    Stage public stage = Stage.FirstCommit;

    constructor(uint _bet, uint _deposit, uint _revealSpan) public {
        bet = _bet;
        deposit = _deposit;
        revealSpan = _revealSpan;
    }

    // TODO: go through and write explicit 'stored' and 'memory' everywhere
    function commit(bytes32 commitment) payable public {
        // only allow commit stages
        uint playerIndex;
        if(stage == Stage.FirstCommit) playerIndex = 0;
        else if(stage == Stage.SecondCommit) playerIndex = 1;
        else revert();

        //TODO: possible overflow
        uint commitAmount = bet + deposit;
        require(msg.value >= commitAmount);
        
        // return any excess
        if(msg.value > commitAmount) msg.sender.transfer(msg.value - commitAmount);
        
        // store the commitment
        players[playerIndex] = CommitChoice(msg.sender, commitment, Choice.None);

        // if we're on the first commit, then move to the second
        if(stage == Stage.FirstCommit) stage = Stage.SecondCommit;
        // otherwise we must already be on the second, move to first reveal
        else stage = Stage.FirstReveal;
    }
    
    function reveal(Choice choice, bytes32 blindingFactor) public {
        require(stage == Stage.FirstReveal || stage == Stage.SecondReveal);
        // only valid choices
        require(choice == Choice.Rock || choice == Choice.Paper || choice == Choice.Scissors);
        
        // find the player index
        uint playerIndex;
        if(players[playerIndex = 0].playerAddress == msg.sender) playerIndex = 0;
        else if (players[1].playerAddress == msg.sender) playerIndex = 1;
        // unknown player
        else revert();

        // find the player data
        CommitChoice storage commitChoice = players[playerIndex]; 

        // check the hash, we have a hash of sender, choice, blind so that players cannot learn anything from a committment
        // if it were just choice, blind the other player could view this and submit it themselves to reliably achieve a draw
        require(keccak256(abi.encodePacked(msg.sender, choice, blindingFactor)) == commitChoice.commitment);
        
        // update if correct
        commitChoice.choice = choice;

        if(stage == Stage.FirstReveal) { 
            // TODO: possible overflow
            // if this is the first reveal we set the deadline for the second one 
            revealDeadline = block.number + revealSpan; 
            // if we're on first reveal, move to the second
            stage = Stage.SecondReveal;
        }
        // if we're on second reveal, move to distribute
        else stage = Stage.Distribute;
    }

    event Payout(address player, uint amount);

    function distribute() public {
        // to distribute we need:
        // a) to be in the distribute stage OR b) still in the second reveal stage but past the deadline
        require(stage == Stage.Distribute || (stage == Stage.SecondReveal && revealDeadline <= block.number));

        // calulate value of payouts for players
        //TODO: possible overflow
        uint player0Payout;
        uint player1Payout;
        uint winningAmount = deposit + 2 * bet;

        // we always draw with the same choices, and we dont lose our deposit even if neither revealed
        if(players[0].choice == players[1].choice) {
            player0Payout = deposit + bet;
            player1Payout = deposit + bet;
        }
        // at least one person has made a choice, otherwise we wouldn't be here
        // in the situation that only one person chose that person wins, and the person
        // who did not will lose their deposit
        else if(players[0].choice == Choice.None) {
            player1Payout = winningAmount;
        }
        else if(players[1].choice == Choice.None) {
            player0Payout = winningAmount;
        }
        // both players have made a choice, and they did not draw
        else if(players[0].choice == Choice.Rock) {
            if(players[1].choice == Choice.Paper) {
                // rock loses to paper
                player0Payout = deposit;
                player1Payout = winningAmount;
            }
            else if(players[1].choice == Choice.Scissors) {
                // rock beats scissors
                player0Payout = winningAmount;
                player1Payout = deposit;
            } 
            else revert();

        }
        else if(players[0].choice == Choice.Paper) {
            if(players[1].choice == Choice.Rock) {
                // paper beats rock
                player0Payout = winningAmount;
                player1Payout = deposit;
            }
            else if(players[1].choice == Choice.Scissors) {
                // paper loses to scissors
                player0Payout = deposit;
                player1Payout = winningAmount;
            }
            else revert();
        }
        else if(players[0].choice == Choice.Scissors) {
            if(players[1].choice == Choice.Rock) {
                // scissors lose to paper
                player0Payout = deposit;
                player1Payout = winningAmount;
            }
            else if(players[1].choice == Choice.Paper) {
                // scissors beats paper
                player0Payout = winningAmount;
                player1Payout = deposit;
            }
            else revert();
        }
        else revert();

        // send the payouts
        if(player0Payout != 0 && players[0].playerAddress.send(player0Payout)){
            emit Payout(players[0].playerAddress, player0Payout);            
        }
        if(player1Payout != 0 && players[1].playerAddress.send(player1Payout)){
            emit Payout(players[1].playerAddress, player1Payout);            
        }

        //reset the state to play again
        delete players;
        revealDeadline = 0;
        stage = Stage.FirstCommit;
    }
}

// ISSUES

// 1. We should pass in the address of the other player to 'commit',
//      then adding a second commit should start the timer

// concerns - assymetry in setting timeout
// concerns - timeout possibly not greatly reduced by addition of deposit

// TODO: look at all the access modifiers for all members and functions
// TODO: what are the consequences?

// TODO: checkout all the integer operations for possible overflows
// TODO: consider event logging


// IMPROVMENTS:

// 1. Allow second player to reveal without committing.
// 2. Allow re-use of the contract? Or allow a self destruct to occur?
// 3. Choose where to send lost deposits.
// 4. Allow a player to forfeit for a cheaper gas cost?


