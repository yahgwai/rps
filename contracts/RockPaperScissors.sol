pragma solidity ^0.4.24;

contract RockPaperScissors {
    enum Choice {
        None,
        Rock,
        Paper,
        Scissors
    }

    enum Stage {
        Commit,
        Reveal,
        Distribute
    }

    struct CommitChoice {
        address playerAddress;
        bytes32 commitment;
        Choice choice;
        bool receivedWinnings;        
    }

    //initialisation args
    uint256 public bet;
    uint256 public deposit;
    uint256 public revealSpan;

    // state vars
    CommitChoice[2] public players;
    uint256 public revealDeadline;
    Stage stage = Stage.Commit;
    uint commitPlayer = 0;

    constructor(uint256 _bet, uint256 _deposit, uint256 _revealSpan) public {
        bet = _bet;
        deposit = _deposit;
        revealSpan = _revealSpan;
    }

    // TODO: go through and write explicit 'stored' and 'memory' everywhere
    function commit(bytes32 commitment) payable public {
        // must be on correct stage, cannot allow commits if two
        require(stage == Stage.Commit);
        //TODO: possible overflow
        uint256 commitAmount = bet + deposit;
        require(msg.value >= commitAmount);
        
        // return any excess
        if(msg.value > commitAmount) msg.sender.transfer(msg.value - commitAmount);
        
        // store the commitment, and the record of the commitment        
        players[commitPlayer] = CommitChoice(msg.sender, commitment, Choice.None, false);

        // move on to the next player
        commitPlayer = commitPlayer + 1;

        // if commitPlayer == 2 then we've had two commits, lets move on to the reveal stage
        if(commitPlayer == 2) stage = Stage.Reveal;
    }
    
    function reveal(Choice choice, bytes32 blindingFactor) public {
        require(stage == Stage.Reveal);
        // only valid choices
        require(choice == Choice.Rock || choice == Choice.Paper || choice == Choice.Scissors);
        
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
        
        // have both players made a choice? if so, move on to distribute stage
        if(players[0].choice != Choice.None && players[1].choice != Choice.None) stage = Stage.Distribute;
    }

    event Payout(address player, uint256 amount);

    function distribute() public {
        // to distribute we need:
        // a) to be in the distribute stage OR b) to be past the deadline
        require(stage == Stage.Distribute || revealDeadline <= block.number);

        // calulate value of payouts for players
        //TODO: possible overflow
        uint256 player0Payout;
        uint256 player1Payout;
        uint256 winningAmount = deposit + 2 * bet;

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
        if(!players[0].receivedWinnings && players[0].playerAddress.send(player0Payout)){
            players[0].receivedWinnings = true;
            emit Payout(players[0].playerAddress, player0Payout);            
        }
        if(!players[1].receivedWinnings && players[1].playerAddress.send(player1Payout)){
            players[1].receivedWinnings = true;
            emit Payout(players[1].playerAddress, player1Payout);            
        }

        if(players[0].receivedWinnings && players[1].receivedWinnings) {
            // both players have received winnings, reset the state to play again
            delete players;
            revealDeadline = 0;
            commitPlayer = 0;
            stage = Stage.Commit;
        }
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


