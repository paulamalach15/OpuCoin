pragma solidity ^0.4.24;

import "./math/SafeMath.sol";
import "./Ownable.sol";
import "./Token/ERC20.sol";

contract Vesting is Ownable {
    using SafeMath for uint;
    using SafeMath for uint256;

    ERC20 token;
    mapping (address => Holding) public holdings;
    address founders;

    uint constant periodInterval = 30 days;
    uint constant foundersHolding = 365 days;
    uint constant bonusHolding = 0;
    uint constant totalPeriods = 12;

    uint public additionalHoldingPool = 0;
    uint totalTokensCommitted = 0;

    bool vestingStarted = false;
    uint vestingStart = 0;

    struct Holding {
        uint tokensCommitted;
        uint tokensRemaining;
        uint batchesClaimed;
        bool updatedForFinalization;
        bool isFounder;
        bool isValue;
    }

    event TokensReleased(address _to, uint _tokensReleased, uint _tokensRemaining);
    event VestingInitialized(address _to, uint _tokens);

    constructor(address _token, address _founders) public {
        require( _token != 0x0);
        require(_founders != 0x0);
        token = ERC20(_token);
        founders = _founders;
    }

    function claimTokens() external {
        require( holdings[msg.sender].isValue );
        require( vestingStarted );
        uint personalVestingStart = 
            (holdings[msg.sender].isFounder) ? (vestingStart.add(foundersHolding)) : (vestingStart);

        require( now > personalVestingStart );

        uint periodsPassed = now.sub(personalVestingStart).div(periodInterval);

        uint batchesToClaim = periodsPassed.sub(holdings[msg.sender].batchesClaimed);
        require( batchesToClaim > 0 );

        if (!holdings[msg.sender].updatedForFinalization) {
            holdings[msg.sender].updatedForFinalization = true;
            holdings[msg.sender].tokensRemaining = (holdings[msg.sender].tokensRemaining).add(
                (holdings[msg.sender].tokensCommitted).div(totalTokensCommitted).mul(additionalHoldingPool)
            );
        }

        uint tokensPerBatch = (holdings[msg.sender].tokensRemaining).div(
            totalPeriods.sub(holdings[msg.sender].batchesClaimed)
        );
        uint tokensToRelease = 0;

        if (periodsPassed >= totalPeriods) {
            tokensToRelease = holdings[msg.sender].tokensRemaining;
            delete holdings[msg.sender];
        } else {
            tokensToRelease = tokensPerBatch.mul(batchesToClaim);
            holdings[msg.sender].tokensRemaining = (holdings[msg.sender].tokensRemaining).sub(tokensToRelease);
        }

        holdings[msg.sender].batchesClaimed = holdings[msg.sender].batchesClaimed.add(batchesToClaim);
        require( token.transfer(msg.sender, tokensToRelease) );
        emit TokensReleased(msg.sender, tokensToRelease, holdings[msg.sender].tokensRemaining);
    }

    function tokensRemainingInHolding(address _user) public view returns (uint) {
        return holdings[_user].tokensRemaining;
    }
    
    function initializeVesting(address _beneficiary, uint _tokens) onlyOwner public {
        bool isFounder = (_beneficiary == founders);
        _initializeVesting(_beneficiary, _tokens, isFounder);
    }

    function finalizeVestingAllocation(uint _holdingPoolTokens) onlyOwner public {
        additionalHoldingPool = _holdingPoolTokens;
        vestingStarted = true;
        vestingStart = now;
    }

    function _initializeVesting(address _to, uint _tokens, bool _isFounder) internal {
        require( !holdings[_to].isValue );

        if (!_isFounder) totalTokensCommitted = totalTokensCommitted.add(_tokens);

        holdings[_to] = Holding({
            tokensCommitted: _tokens, 
            tokensRemaining: _tokens,
            batchesClaimed: 0, 
            updatedForFinalization: (_isFounder) ? (true) : (false), 
            isFounder: _isFounder,
            isValue: true
        });

        emit VestingInitialized(_to, _tokens);
    }
}
