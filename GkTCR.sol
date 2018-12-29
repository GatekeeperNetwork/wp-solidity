pragma solidity ^0.5.2;
import "./ECRecovery.sol";
import "./ERC20.sol";
import "./USECard.sol";

contract GkTCR{

    using SafeMath for uint256;

    uint256 usePostingReward = 500000; //amount of USE the Review Room Keeper gets per posted review...placeholder.
    address useTokenAddress = 0x8e1422fEec8CA59bb89f002028a36C969B90D85f;

    function postRating(bytes memory encodedRating, bytes memory sig) public{
        bytes32 hash = keccak256(encodedRating);
        address consumer = ECRecovery.recover(hash, sig);
        (address deviceID, uint16 rating, uint256 threadID, uint32 txCount) = abi.decode(encodedRating, (address, uint16, uint256, uint32));
        require(USECard.threads[consumer][deviceID][threadID].txCount > lastTxCountRated[consumer][deviceID]); //make sure this hasn't been rated yet
        uint256 newUseWeight = lastUSEAmountRated[consumer][deviceID].sub(USECard.threads[consumer][deviceID][threadID].tokenBalances[1]); //ignoring bidirectionality

        DeviceRating storage newRating = TCRRatings[deviceID][lastRatingPosted[deviceID]];
        //create new rating
        newRating.consumer = consumer;
        newRating.useValue = newUseWeight;
        newRating.rating = rating;
        newRating.block = now;

        lastRatingPosted[deviceID]++; //increment device<>consumer rating
        TCRRatings[deviceID][lastRatingPosted[deviceID]][newRating]; //post new rating
        ERC20(useTokenAddress).transfer(address(this), msg.sender, usePostingReward); //reward Review Room Keeper

    }

    function hashRating(address deviceID, uint16 rating, uint256 threadID, uint32 txCount) public pure returns (bytes32){
        return keccak256(encodeRating(deviceID,rating,threadID,txCount));
    }

    function encodeRating(address deviceID, uint16 rating, uint256 threadID, uint32 txCount) public pure returns(bytes memory encodeRating){
        return abi.encode(deviceID,rating,threadID,txCount);
    }

    function decodeRating(bytes memory encodedRating) public returns (address deviceID, uint16 rating, uint256 threadID, uint32 txCount){
        return abi.decode(encodedRating, (address, uint16, uint256, uint32));
    }
    struct DeviceRating{
        address consumer;
        uint256 useValue;
        uint16  rating;
        uint256 block;
    }

    //Posted Ratings
    mapping(address => mapping(uint256 => DeviceRating)) TCRRatings; //[deviceID][deviceRatingIndex][DeviceRating]
    mapping(address => uint256) lastRatingPosted; //[deviceID][deviceRatingIndex]
    mapping(address => uint256) lastRatingProcessed; //[deviceID][deviceRatingIndex]

    //Calculated Ratings
    mapping(address => uint256) totalUSERated; //[deviceID][amountUSE]
    mapping(address => uint256) currentWeight;

    mapping(address => mapping(address => uint256)) lastUSEAmountRated; //last amount of USE weight between consumer and provider
    mapping(address => mapping(address => uint256)) lastTxCountRated;

    function calculateDeviceRating(address deviceID) public returns(uint256 newRating){
        uint256 lastProcessed = lastRatingProcessed[deviceID];
        uint256 totalUSE = totalUSERated[deviceID];
        uint256 weightedReview = currentWeight[deviceID];

        for(lastProcessed; lastProcessed< lastRatingPosted[deviceID]; lastProcessed++){
            totalUSE += TCRRatings[deviceID][lastProcessed].useValue;
            weightedReview += TCRRatings[deviceID][lastProcessed].useValue.mul(TCRRatings[deviceID][lastProcessed].rating);
        }
        lastRatingProcessed[deviceID] = lastProcessed;
        totalUSERated[deviceID] = totalUSE;
        currentWeight[deviceID] = weightedReview;

        return weightedReview.div(totalUSE);
    }

    function getDeviceRating(address deviceID) public returns(uint256 deviceRating) {
        return currentWeight[deviceID] / totalUSERated[deviceID];
    }

}