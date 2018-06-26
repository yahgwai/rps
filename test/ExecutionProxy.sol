pragma solidity ^0.4.2;
import "../contracts/RockPaperScissors.sol";

// adapted from https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests
contract ExecutionProxy {
    address public target;
    bytes data;
    uint256 value;

    constructor(address _target) public {
        target = _target;
    }

    // TODO: keep these logging events?
    event Fallback(address sender, bytes data, uint256 value);
    event FallbackSetData(bytes data, uint256 value);

    function() payable public {
        emit Fallback(msg.sender, msg.data, msg.value);
        data = msg.data;
        value = msg.value;
        emit FallbackSetData(data, value);
    }

    function execute() public returns (bool) {
        return target.call.value(value)(data);
    }
}