pragma solidity ^0.4.18;

import "./interfaces/ERC223.sol";
import "./SafeMath.sol";

contract Vesting is SafeMath {
    ERC223 token;
    mapping (address => Holding) public holdings;
    address backend;

    uint constant periodInterval = 30 days;
    uint8 constant totalPeriods = 12;

    struct Holding {
        uint tokensRemaining;
        uint tokensPerBatch;
        uint lockupEnds;
        uint8 periodsPassed;
        uint nextPeriod;
        bool isValue;
    }

    event TokensReleased(address _to, uint _tokensReleased, uint _tokensRemaining);
    event VestingInitialized(address _to, uint _tokens);

    function Vesting(address _token) public {
        require( _token != 0x0);
        token = ERC223(_token);
        backend = msg.sender;
    }

    function claimTokens() external {
        require( holdings[msg.sender].isValue );
        require( now > holdings[msg.sender].lockupEnds );
        require( now > holdings[msg.sender].nextPeriod );

        uint tokensToRelease = 0;
        uint tokensRemaining = holdings[msg.sender].tokensRemaining;

        do {
            holdings[msg.sender].periodsPassed += 1;
            holdings[msg.sender].nextPeriod += periodInterval;
            tokensToRelease += holdings[msg.sender].tokensPerBatch;
        } while ((now > holdings[msg.sender].nextPeriod) && 
                 (holdings[msg.sender].periodsPassed <= totalPeriods));

        tokensRemaining -= tokensToRelease;

        // If vesting has finished, just transfer the remaining tokens.
        if (holdings[msg.sender].periodsPassed == totalPeriods) {
            tokensToRelease = holdings[msg.sender].tokensRemaining;
            // And delete the record
            delete holdings[msg.sender];
        } else {
            holdings[msg.sender].tokensRemaining = tokensRemaining;
        }


        bytes memory empty;
        if ( token.transfer(msg.sender, tokensToRelease, empty) ) {
            TokensReleased(msg.sender, tokensToRelease, tokensRemaining);
        } else {
            revert();
        }
    }

    function tokenFallback(address _from, uint _tokens, bytes data) public {
        require( msg.sender == address(token) );
        require( _from == backend );
        initializeVesting(bytesToAddress(data), _tokens, 1, totalPeriods);
    }

    function initializeVesting(address _to, uint _tokens, uint8 _yearsHolding, uint _periods) internal {
        uint tokensPerBatch;
        uint lockupEnds = safeAdd(now, safeMul(_yearsHolding, 365 days));
        uint nextPeriod;

        assert( _periods != 0 );
        tokensPerBatch = _tokens / _periods;
        nextPeriod = safeAdd(lockupEnds, 30 days);

        holdings[_to] = Holding(_tokens, 
                                tokensPerBatch, 
                                lockupEnds, 
                                0, 
                                nextPeriod, 
                                true);

        VestingInitialized(_to, _tokens);
    }
    /*
    struct Holding {
        uint tokens;
        uint tokensPerBatch;
        uint lockupEnds;
        uint periodsPassed;
        uint nextPeriod;
        bool isValue;
        }
        */

    function bytesToAddress(bytes _b) internal pure returns (address) {
        uint160 m = 0;
        uint160 b = 0;

        for (uint8 i = 0; i < 20; i++) {
            m *= 256;
            b = uint160(_b[i]);
            m += (b);
        }

        return address(m);
        }
}
