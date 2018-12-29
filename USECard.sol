pragma solidity ^0.5.2;
import "./ChannelManager.sol"; //Connext

contract USECard is ChannelManager{


    struct Thread {
        uint256[2] weiBalances; // [sender, receiver]
        uint256[2] tokenBalances; // [sender, receiver]
        uint256 txCount; // persisted onchain even when empty
        uint256 threadClosingTime;
        bool[2] emptied; // [sender, receiver]
    }

    // mapping(address => Channel) public channels;
    mapping(address => mapping(address => mapping(uint256 => Thread))) threads; // threads[sender][receiver][threadId]

}