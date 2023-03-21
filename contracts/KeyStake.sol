//"SPDX-License-Identifier: MIT"

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./Keys.sol";
import "./Irandomizer.sol";
import "./AdminRole.sol";
import "./IProps.sol";

abstract contract MansonRiveState
{
    event KeysStaked(
        address indexed _owner,
        uint256 indexed _tokenId,
        uint256 _stakeTime
    );
    event KeysUnstaked(address indexed _owner,  uint256 indexed _tokenId, uint256 _stakingPeriod);

    event StartClaiming(
        address indexed _owner,
        uint256 indexed _tokenId,
        uint256 _requestId,
        uint256 _numberRewards
    );
    event RewardClaimed(
        address indexed _owner,
        uint256 indexed _tokenId,
        uint256 _claimedRewardId,
        uint256 _amount
    );

  
    MansonRiveKeys public keys;
    IProps public props;
    IRandomizer public randomizer;


    // collection address -> tokenId -> info
    // mapping(uint256 => uint256) public tokenIdToStakeStartTime;
    mapping(uint256 => uint256) public tokenIdToRewardsClaimed;
    mapping(uint256 => uint256) public tokenIdToRequestId;
    mapping(uint256 => uint256) public tokenIdToRewardsInProgress;

    uint256[] public rewardOptions;
    // Odds out of 100,000
    mapping(uint256 => uint32) public rewardIdToOdds;

    uint256 public _timeForReward;

    modifier onlyEOA() {
        /* solhint-disable avoid-tx-origin */
        require(msg.sender == tx.origin, "No contracts");
        _;
    }
}




//Staking Contract

contract MansonRiveKeyStake is MansonRiveState, AdminRole {

    uint public totalStaked;

    struct Stake {
        uint24 tokenId;
        uint48 timeStamp;
        address owner;
    }
  
    //Modifier to check whether contracts are set
      modifier contractsAreSet() {
        require(address(keys) != address(0)
            && address(randomizer) != address(0)
            && address(props) != address(0), "Contracts aren't set");
        _;
    }
    //mapping of tokenId to stake struct, which contains staking details
    mapping(uint => Stake) public mansonVault;

    //mapping of staker address to the total staking period
    mapping(address => uint) public stakingPeriod;


    constructor(address _keys, address _props, address _randomizer) {
        keys = MansonRiveKeys (_keys);
        props = IProps (_props);
        randomizer = IRandomizer (_randomizer);
        _timeForReward = 5 minutes;
    }


    function setRewards(
        uint256[] calldata _rewardIds,
        uint32[] calldata _rewardOdds)
    external
    onlyAdminOrOwner
    // nonZeroLength(_rewardIds)
    {
        require(_rewardIds.length == _rewardOdds.length, "Bad lengths");

        delete rewardOptions;

        uint32 _totalOdds;
        for(uint256 i = 0; i < _rewardIds.length; i++) {
            _totalOdds += _rewardOdds[i];

            rewardOptions.push(_rewardIds[i]);
            rewardIdToOdds[_rewardIds[i]] = _rewardOdds[i];
        }

        require(_totalOdds == 50000, "Bad total odds");
    }


    function stakeKeys(uint256[] calldata _tokenIds) external  {
        require(_tokenIds.length > 0, "no tokens inputed");
        uint256 _tokenId;
        totalStaked += _tokenIds.length;
        for(uint i = 0; i < _tokenIds.length; i++) {
            _tokenId = _tokenIds[i];
            require(keys.ownerOf(_tokenId) == msg.sender, "not your token");
            require(mansonVault[_tokenId].tokenId == 0, "already staked");

            keys.transferFrom(msg.sender, address(this), _tokenId);
            emit KeysStaked(msg.sender, _tokenId, block.timestamp);

            mansonVault[_tokenId] = Stake ({

                owner: msg.sender,
                tokenId: uint24(_tokenId),
                timeStamp: uint48(block.timestamp)
            });
        }
        
    }


    function unstakeKeys(
        uint256[] calldata _tokenIds)
    external
    onlyEOA
    contractsAreSet
    {
        totalStaked -= _tokenIds.length;
        require(_tokenIds.length > 0, "no token given");
        for (uint i = 0; i < _tokenIds.length; i++) {
            _unstakeKeys(_tokenIds[i]);
        }
    }
    
    
    function _unstakeKeys(uint256 _tokenId) private {
        
            Stake memory staked = mansonVault[_tokenId];
            require(staked.owner == msg.sender, "not the Owner");
            require(tokenIdToRequestId[_tokenId] == 0, "Claim in progress");
            require(numberOfRewardsToClaim(_tokenId) == 0, "Rewards left unclaimed!");

            delete mansonVault[_tokenId];
            delete tokenIdToRewardsClaimed[_tokenId];

            emit KeysUnstaked(msg.sender, _tokenId, block.timestamp);
            keys.transferFrom(address(this), msg.sender, _tokenId);
            stakingPeriod[msg.sender] = (block.timestamp - mansonVault[_tokenId].timeStamp);
        }
        
    function startClaimingRewards(
        uint256[] calldata _tokenIds)
    external
    onlyEOA
    contractsAreSet
    // whenNotPaused
    {
        require(_tokenIds.length > 0, "no tokens given");
        for(uint256 i = 0; i < _tokenIds.length; i++) {
           _startClaimingReward( _tokenIds[i]);
        }
    }

    function _startClaimingReward(uint256 _tokenId) private {
        Stake memory staked = mansonVault[_tokenId];
        require(staked.owner == msg.sender, "not the Owner");
        require(tokenIdToRequestId[_tokenId] == 0, "Claim in progress");

        uint256 _numberToClaim = numberOfRewardsToClaim(_tokenId);
        require(_numberToClaim > 0, "No rewards to claim");

        tokenIdToRewardsClaimed[_tokenId] += _numberToClaim;
        tokenIdToRewardsInProgress[_tokenId] = _numberToClaim;

        uint256 _requestId = randomizer.requestRandomNumber();
        tokenIdToRequestId[_tokenId] = _requestId;

        emit StartClaiming(msg.sender, _tokenId, _requestId, _numberToClaim);
    }

    function finishClaimingRewards(
        uint256[] calldata _keyTokenIds)
    external
    onlyEOA
    contractsAreSet
    // whenNotPaused
    {
        require(_keyTokenIds.length > 0, "no tokens given");
        for(uint256 i = 0; i < _keyTokenIds.length; i++) {
           _finishClaimingReward(_keyTokenIds[i]);
        }
    }

    function _finishClaimingReward(uint256 _tokenId) private {
        Stake memory staked = mansonVault[_tokenId];
        require(staked.owner == msg.sender, "not the Owner");
        require(rewardOptions.length > 0, "Rewards not setup");

        uint256 _requestId = tokenIdToRequestId[_tokenId];
        require(_requestId != 0, "No claim in progress");

        require(randomizer.isRandomReady(_requestId), "Random not ready");

        uint256 _randomNumber = randomizer.revealRandomNumber(_requestId);

        uint256 _numberToClaim = tokenIdToRewardsInProgress[_tokenId];

        for(uint256 i = 0; i < _numberToClaim; i++) {
            if(i != 0) {
                _randomNumber = uint256(keccak256(abi.encode(_randomNumber, i)));
            }

            _claimReward(_tokenId, _randomNumber);
        }

        delete tokenIdToRewardsInProgress[_tokenId];
        delete tokenIdToRequestId[_tokenId];
    }

    function _claimReward(uint256 _tokenId, uint256 _randomNumber) private {
        uint256 _rewardResult = _randomNumber % 50000;

        uint256 _topRange = 0;
        uint256 _claimedRewardId = 0;
        for(uint256 i = 0; i < rewardOptions.length; i++) {
            uint256 _rewardId = rewardOptions[i];
            _topRange += rewardIdToOdds[_rewardId];
            if(_rewardResult < _topRange) {
                _claimedRewardId = _rewardId;
                
                props.mintPropsType(msg.sender, _claimedRewardId, 1);

                break;
            }
        }

        emit RewardClaimed(msg.sender, _tokenId, _claimedRewardId, 1);
    }


 function numberOfRewardsToClaim(uint256 _tokenId) public view returns(uint256) {
        Stake memory staked = mansonVault[_tokenId];
        uint stakedAt = staked.timeStamp;
        if(stakedAt == 0) {
            return 0;
        }

        uint256 _timeForCalculation = stakedAt + (tokenIdToRewardsClaimed[_tokenId] * _timeForReward);

        return (block.timestamp - _timeForCalculation) / _timeForReward;
    }

    function setTimeForReward(uint256 _rewardTime) external onlyAdminOrOwner {
        _timeForReward = _rewardTime;
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 balance = 0;
        uint256 supply = keys.totalSupply();
        for(uint i = 1; i <= supply; i++) {
            if (mansonVault[i].owner == account) {
                balance += 1;
            }
        }
        return balance;
    }

  
    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
     ) external pure returns (bytes4) {
         require(from == address(0x0), "Cannot send nfts to mansonVault directly");
         return IERC721Receiver.onERC721Received.selector;       

    }

}