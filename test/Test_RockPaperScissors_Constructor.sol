pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RockPaperScissors.sol";

contract Test_RockPaperScissors_Constructor {
    uint256 public initialBalance = 10 ether;
    uint256 commitAmount = 100;

    function testConstructorSetbalance() public {
        RockPaperScissors rps = new RockPaperScissors(commitAmount);
        
        Assert.equal(rps.bet(), commitAmount, "Contract bet amount does not equal supplied bet amount.");
    }
}