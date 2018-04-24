pragma solidity ^0.4.18;

import "./interfaces/ERC223.sol";

contract ColdStorage {
    ERC223 token;
    address backend;

    event StorageInitialized(address _to, uint _tokens);
    event TokensReleased(address _to, uint _tokensReleased);

    uint public lockupEnds;
    address public team;

    function ColdStorage(address _token) public {
        require( _token != 0x0 );
        token = ERC223(_token);
        backend = msg.sender;
    }

    function claimTokens() external {
        require( now > lockupEnds );
        require( msg.sender == team );

        uint tokensToRelease = token.balanceOf(address(this));
        bytes memory empty;
        if ( token.transfer(msg.sender, tokensToRelease, empty) ) {
            TokensReleased(msg.sender, tokensToRelease);
        } else {
            revert();
        }
    }

    function tokenFallback(address _from, uint _tokens, bytes data) public {
        require( msg.sender == address(token) );
        require( _from == backend );
        initializeHolding(bytesToAddress(data), _tokens);
    }

    function initializeHolding(address _to, uint _tokens) internal {
        lockupEnds = now + 2 * 365 days;
        team = _to;
        StorageInitialized(_to, _tokens);
    }

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
