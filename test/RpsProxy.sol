pragma solidity ^0.4.2;

import "../contracts/RockPaperScissors.sol";

contract RpsProxy {
    RockPaperScissors public rps;

    constructor(RockPaperScissors _rps) public {
        rps = _rps;
    }

    function commit(bytes32 commitment) payable public {
        this.rps().commit.value(msg.value)(commitment);
    }
}