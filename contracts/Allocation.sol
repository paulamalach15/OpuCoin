pragma solidity ^0.4.18;

import "./interfaces/ERC223.sol";
import "./ColdStorage.sol";
import "./Vesting.sol";

contract Allocation {
    address public manager;
    address public backend;
    address public team;
    address public partners;
    address public toSendFromStorage;
    address public networkStorage;
    ERC223 public token;
    Vesting public vesting;
    ColdStorage public coldStorage;

    bool public tokensReceived = false;
    uint public holdingParticipants;
    uint public unsoldTokens;
    uint8[10] public bonusTable = [50, 40, 35, 30, 25, 20, 15, 10, 5, 0];
    uint8 public bonusStage = 0;
    uint8 finalizationStage = 0;

    bool public emergencyPaused = false;

    uint constant mil = 1e6 * 1e18;
    uint entireSupply = 12 * 1e9 * 1e18;
    // Token distribution table, all values in millions of tokens
    uint constant teamTokens           = 1260 * mil;
    uint constant partnersTokens       =  480 * mil; 
    uint constant coldStorageTokens    =  600 * mil;
    uint constant networkStorageTokens = 8880 * mil;
    uint constant sellableTokens       =  780 * mil;

    event TokensAllocated(address _buyer, uint _tokens);
    event TokensAllocatedIntoHolding(address _buyer, uint _tokens);
    event TokensSentIntoVesting(address _vesting, address _to, uint _tokens);
    event TokensSentIntoHolding(address _vesting, address _to, uint _tokens);
    event AllocationFinished();

    // Human interaction (only accepted from the address that launched the contract)
    function Allocation(address _backend, address _token, address _team, 
                        address _partners, address _toSendFromStorage, address _networkStorage) public {
        require( _backend           != 0x0 );
        require( _token             != 0x0 );
        require( _team              != 0x0 );
        require( _partners          != 0x0 );
        require( _toSendFromStorage != 0x0 );
        require( _networkStorage    != 0x0 );

        manager           = msg.sender;
        backend           = _backend;
        token             = ERC223(_token);
        team              = _team;
        partners          = _partners;
        toSendFromStorage = _toSendFromStorage;
        networkStorage    = _networkStorage;

        vesting = new Vesting(address(token));
        coldStorage = new ColdStorage(address(token));
    }

    function emergencyPause() public owned(manager) unpaused {
        emergencyPaused = true;
    }

    function emergencyUnpause() public owned(manager) paused {
        emergencyPaused = false;
    }

    // Backend interaction (only accepted from the address specified at launch)
    function initializeAllocation(uint _holdingParticipants, uint _unsoldTokens) public owned(backend) {
        require(_unsoldTokens <= sellableTokens );
        holdingParticipants = _holdingParticipants;
        unsoldTokens = _unsoldTokens;
    }

    function allocate(address _buyer, uint _tokensBeforeBonuses, 
                                      uint _referralBonusTokens) public owned(backend) unpaused {
        require( _buyer != 0x0 );

        // Calculate the total token sum to allocate
        uint tokensToAllocate = calculateTokensToAllocate(_tokensBeforeBonuses, _referralBonusTokens);

        // Send the transfer
        bytes memory empty;
        token.transfer(_buyer, tokensToAllocate, empty);
        TokensAllocated(_buyer, tokensToAllocate);
    }

    function allocateIntoHolding(address _buyer, uint _tokensBeforeBonuses, 
                                                 uint _referralBonusTokens) public owned(backend) unpaused {
        require( _buyer != 0x0 );

        // Calculate the total token sum to allocate
        uint tokensToAllocate = calculateTokensToAllocate(_tokensBeforeBonuses, _referralBonusTokens);
        tokensToAllocate += unsoldTokens / holdingParticipants;

        // Send the transfer
        token.transfer(address(vesting), tokensToAllocate, toBytes(_buyer));
        TokensAllocatedIntoHolding(_buyer, tokensToAllocate);
    }

    function advanceBonusPhase() public owned(backend) unpaused returns (uint8) {
        require( bonusStage < bonusTable.length - 1);
        bonusStage += 1;
        return bonusStage;
    }

    function finalizeAllocation() public owned(backend) unpaused {
        require( finalizationStage <= 3);
        if (finalizationStage == 0) {
            vestTokens(team, teamTokens);
        } else if (finalizationStage == 1) {
            vestTokens(partners, partnersTokens);
        } else if (finalizationStage == 2) {
            holdTokens(toSendFromStorage, coldStorageTokens);
        } else if (finalizationStage == 3) {
            bytes memory empty;
            token.transfer(networkStorage, networkStorageTokens, empty);
            AllocationFinished();
        }
        finalizationStage += 1;
    }

    function tokenFallback(address _from, uint _tokens, bytes _data) public {
        require(_from == 0x0);
        require(_tokens == entireSupply);
        require(!tokensReceived);
        tokensReceived = true;
    }

    function vestTokens(address _to, uint _tokens) internal {
        token.transfer(address(vesting), _tokens, toBytes(_to));
        TokensSentIntoVesting(address(vesting), _to, _tokens);
    }

    function holdTokens(address _to, uint _tokens) internal {
        token.transfer(address(coldStorage), _tokens, toBytes(_to));
        TokensSentIntoHolding(address(coldStorage), _to, _tokens);
    }

    function calculateTokensToAllocate(uint _tokensBeforeBonuses, uint _referralBonus) 
                internal view returns (uint) {
        uint stageBonus = _tokensBeforeBonuses * bonusTable[bonusStage] / 100;
        uint tokensToAllocate = _tokensBeforeBonuses + stageBonus + _referralBonus;
        assert( tokensToAllocate >= _tokensBeforeBonuses );
        return tokensToAllocate;
    }

    function toBytes(address a) internal pure returns (bytes b) {
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
            mstore(0x40, add(m, 52))
            b := m
        }
    }

    modifier owned(address _owner) {
        require( msg.sender == _owner );
        _;
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
