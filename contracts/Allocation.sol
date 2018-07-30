pragma solidity ^0.4.24;

import "./math/SafeMath.sol";
import "./ColdStorage.sol";
import "./OPUCoin.sol";
import "./Ownable.sol";
import "./Vesting.sol";

contract Allocation is Ownable {
    using SafeMath for uint256;

    address public backend;
    address public team;
    address public partners;
    address public toSendFromStorage;
    OPUCoin public token;
    Vesting public vesting;
    ColdStorage public coldStorage;

    uint public holdingParticipants;
    uint public holdingAllocations = 0;
    uint public holdingPool;
    uint8 finalizationStage = 0;

    bool public emergencyPaused = false;
    bool public finalizedHoldingsAndTeamTokens = false;

    uint constant mil = 1e6 * 1e18;
    // Token distribution table, all values in millions of tokens
    uint constant icoDistribution   = 1350 * mil;
    uint constant teamTokens        = 675  * mil;
    uint constant coldStorageTokens = 189  * mil;
    uint constant partnersTokens    = 297  * mil; 
    uint constant rewardsPool       = 189  * mil;

    uint totalTokensSold = 0;
    uint totalTokensRewarded = 0;

    event TokensAllocated(address _buyer, uint _tokens);
    event TokensAllocatedIntoHolding(address _buyer, uint _tokens);
    event TokensMintedForRedemption(address _to, uint _tokens);
    event TokensSentIntoVesting(address _vesting, address _to, uint _tokens);
    event TokensSentIntoHolding(address _vesting, address _to, uint _tokens);
    event HoldingAndTeamTokensFinalized();

    // Human interaction (only accepted from the address that launched the contract)
    constructor(address _backend, address _team, address _partners, address _toSendFromStorage) public {
        require( _backend           != 0x0 );
        require( _team              != 0x0 );
        require( _partners          != 0x0 );
        require( _toSendFromStorage != 0x0 );

        backend           = _backend;
        team              = _team;
        partners          = _partners;
        toSendFromStorage = _toSendFromStorage;

        token       = new OPUCoin();
        vesting     = new Vesting(address(token), team);
        coldStorage = new ColdStorage(address(token));
    }

    function emergencyPause() public onlyOwner unpaused { emergencyPaused = true; }

    function emergencyUnpause() public onlyOwner paused { emergencyPaused = false; }

    function allocate(
        address _buyer, 
        uint _tokensWithStageBonuses, 
        uint _rewardsBonusTokens
    ) 
        public 
        ownedBy(backend) 
        unpaused 
    {
        uint tokensAllocated = _allocateTokens(_buyer, _tokensWithStageBonuses, _rewardsBonusTokens);
        emit TokensAllocated(_buyer, tokensAllocated);
    }

    function allocateIntoHolding(
        address _buyer, 
        uint _tokensWithStageBonuses, 
        uint _rewardsBonusTokens
    ) 
        public 
        ownedBy(backend) 
        unpaused 
    {
        require( !finalizedHoldingsAndTeamTokens );
        uint tokensAllocated = _allocateTokens(
            address(vesting), 
            _tokensWithStageBonuses, 
            _rewardsBonusTokens
        );
        vesting.initializeVesting(_buyer, tokensAllocated);
        emit TokensAllocatedIntoHolding(_buyer, tokensAllocated);
    }

    function mintForRedemption(address _to, uint _tokens) public ownedBy(backend) unpaused {
        require( _to != 0x0 );
        token.mint(_to, _tokens);
        emit TokensMintedForRedemption(_to, _tokens);
    }

    function finalizeHoldingAndTeamTokens(uint _holdingPoolTokens) public ownedBy(backend) unpaused {
        require( !finalizedHoldingsAndTeamTokens );

        finalizedHoldingsAndTeamTokens = true;

        // Can exceed ICO token cap
        token.mint(address(vesting), _holdingPoolTokens);
        vesting.finalizeVestingAllocation(_holdingPoolTokens);

        vestTokens(team, teamTokens);
        holdTokens(toSendFromStorage, coldStorageTokens);
        token.mint(partners, partnersTokens);
        emit HoldingAndTeamTokensFinalized();
    }

    function optAddressIntoHolding(address _holder, uint _tokens) public ownedBy(backend) {
        require( !finalizedHoldingsAndTeamTokens );

        require( token.transfer(address(vesting), _tokens) );

        vesting.initializeVesting(_holder, _tokens);
        emit TokensSentIntoHolding(address(vesting), _holder, _tokens);
    }

    function _allocateTokens(
        address _to, 
        uint _tokensWithStageBonuses, 
        uint _rewardsBonusTokens
    ) 
        internal 
        unpaused 
        returns (uint)
    {
        require( _to != 0x0 );

        checkCapsAndUpdate(_tokensWithStageBonuses, _rewardsBonusTokens);

        // Calculate the total token sum to allocate
        uint tokensToAllocate = _tokensWithStageBonuses.add(_rewardsBonusTokens);

        // Mint the tokens
        require( token.mint(_to, tokensToAllocate) );
        return tokensToAllocate;
    }

    function checkCapsAndUpdate(uint _tokensToSell, uint _tokensToReward) internal {
        uint newTotalTokensSold = totalTokensSold.add(_tokensToSell);
        require( newTotalTokensSold <= icoDistribution );
        totalTokensSold = newTotalTokensSold;

        uint newTotalTokensRewarded = totalTokensRewarded.add(_tokensToReward);
        require( newTotalTokensRewarded <= rewardsPool );
        totalTokensRewarded = newTotalTokensRewarded;
    }

    function vestTokens(address _to, uint _tokens) internal {
        require( token.mint(address(vesting), _tokens) );
        vesting.initializeVesting( _to, _tokens );
        emit TokensSentIntoVesting(address(vesting), _to, _tokens);
    }

    function holdTokens(address _to, uint _tokens) internal {
        require( token.mint(address(coldStorage), _tokens) );
        coldStorage.initializeHolding(_to, _tokens);
        emit TokensSentIntoHolding(address(coldStorage), _to, _tokens);
    }

    modifier unpaused() {
        require( !emergencyPaused );
        _;
    }

    modifier paused() {
        require( emergencyPaused );
        _;
    }
}
