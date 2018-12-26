pragma solidity 0.4.24;

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

    bool public emergencyPaused = false;
    bool public finalizedHoldingsAndTeamTokens = false;
    bool public mintingFinished = false;

    // All the numbers on the following 8 lines are lower than 10^30
    // Which is in turn lower than 2^105, which is lower than 2^256
    // So, no overflows are possible, the operations are safe.
    uint constant internal MIL = 1e6 * 1e18;
    // Token distribution table, all values in millions of tokens
    uint constant internal ICO_DISTRIBUTION    = 1350 * MIL;
    uint constant internal TEAM_TOKENS         = 675  * MIL;
    uint constant internal COLD_STORAGE_TOKENS = 189  * MIL;
    uint constant internal PARTNERS_TOKENS     = 297  * MIL; 
    uint constant internal REWARDS_POOL        = 189  * MIL;

    uint internal totalTokensSold = 0;
    uint internal totalTokensRewarded = 0;

    event TokensAllocated(address _buyer, uint _tokens);
    event TokensAllocatedIntoHolding(address _buyer, uint _tokens);
    event TokensMintedForRedemption(address _to, uint _tokens);
    event TokensSentIntoVesting(address _vesting, address _to, uint _tokens);
    event TokensSentIntoHolding(address _vesting, address _to, uint _tokens);
    event HoldingAndTeamTokensFinalized();
    event BackendUpdated(address oldBackend, address newBackend);
    event TeamUpdated(address oldTeam, address newTeam);
    event PartnersUpdated(address oldPartners, address newPartners);
    event ToSendFromStorageUpdated(address oldToSendFromStorage, address newToSendFromStorage);

    // Human interaction (only accepted from the address that launched the contract)
    constructor(
        address _backend, 
        address _team, 
        address _partners, 
        address _toSendFromStorage
    ) 
        public 
    {
        require( _backend           != address(0) );
        require( _team              != address(0) );
        require( _partners          != address(0) );
        require( _toSendFromStorage != address(0) );

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
        mintingEnabled
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
        mintingEnabled
    {
        uint tokensAllocated = _allocateTokens(
            address(vesting), 
            _tokensWithStageBonuses, 
            _rewardsBonusTokens
        );
        vesting.initializeVesting(_buyer, tokensAllocated);
        emit TokensAllocatedIntoHolding(_buyer, tokensAllocated);
    }

    function finalizeHoldingAndTeamTokens(
        uint _holdingPoolTokens
    ) 
        public 
        ownedBy(backend) 
        unpaused 
    {
        require( !finalizedHoldingsAndTeamTokens );

        finalizedHoldingsAndTeamTokens = true;

        vestTokens(team, TEAM_TOKENS);
        holdTokens(toSendFromStorage, COLD_STORAGE_TOKENS);
        token.mint(partners, PARTNERS_TOKENS);

        // Can exceed ICO token cap
        token.mint(address(vesting), _holdingPoolTokens);
        vesting.finalizeVestingAllocation(_holdingPoolTokens);

        mintingFinished = true;
        token.finishMinting();

        emit HoldingAndTeamTokensFinalized();
    }

    function optAddressIntoHolding(
        address _holder, 
        uint _tokens
    ) 
        public 
        ownedBy(backend) 
    {
        require( !finalizedHoldingsAndTeamTokens );

        require( token.mint(address(vesting), _tokens) );

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
        require( _to != address(0) );

        checkCapsAndUpdate(_tokensWithStageBonuses, _rewardsBonusTokens);

        // Calculate the total token sum to allocate
        uint tokensToAllocate = _tokensWithStageBonuses.add(_rewardsBonusTokens);

        // Mint the tokens
        require( token.mint(_to, tokensToAllocate) );
        return tokensToAllocate;
    }

    function checkCapsAndUpdate(uint _tokensToSell, uint _tokensToReward) internal {
        uint newTotalTokensSold = totalTokensSold.add(_tokensToSell);
        require( newTotalTokensSold <= ICO_DISTRIBUTION );
        totalTokensSold = newTotalTokensSold;

        uint newTotalTokensRewarded = totalTokensRewarded.add(_tokensToReward);
        require( newTotalTokensRewarded <= REWARDS_POOL );
        totalTokensRewarded = newTotalTokensRewarded;
    }

    function vestTokens(address _to, uint _tokens) internal {
        require( token.mint(address(vesting), _tokens) );
        vesting.initializeVesting( _to, _tokens );
        emit TokensSentIntoVesting(address(vesting), _to, _tokens);
    }

    function holdTokens(address _to, uint _tokens) internal {
        require( token.mint(address(coldStorage), _tokens) );
        coldStorage.initializeHolding(_to);
        emit TokensSentIntoHolding(address(coldStorage), _to, _tokens);
    }

    function updateBackend(address _newBackend) public onlyOwner {
        require(_newBackend != address(0));
        backend = _newBackend;
        emit BackendUpdated(backend, _newBackend);
    }

    function updateTeam(address _newTeam) public onlyOwner {
        require(_newTeam != address(0));
        team = _newTeam;
        emit TeamUpdated(team, _newTeam);
    }

    function updatePartners(address _newPartners) public onlyOwner {
        require(_newPartners != address(0));
        partners = _newPartners;
        emit PartnersUpdated(partners, _newPartners);
    }

    function updateToSendFromStorage(address _newToSendFromStorage) public onlyOwner {
        require(_newToSendFromStorage != address(0));
        toSendFromStorage = _newToSendFromStorage;
        emit ToSendFromStorageUpdated(toSendFromStorage, _newToSendFromStorage);
    }

    modifier unpaused() {
        require( !emergencyPaused );
        _;
    }

    modifier paused() {
        require( emergencyPaused );
        _;
    }

    modifier mintingEnabled() {
        require( !mintingFinished );
        _;
    }
}
