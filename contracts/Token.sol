pragma solidity ^0.4.18;

contract Token {
    mapping (address => uint) public balances;
    mapping (address => mapping (address => uint)) public allowed;


	// Events
	event Approval(address indexed _tokenOwner, address indexed _spender, uint _tokens);
	// ERC20 Transfer event, added for compatibility, can be disabled once and forever
	event Transfer(address indexed _from, address indexed _to, uint _tokens);
	// ERC223 Transfer event
	event Transfer(address indexed _from, address indexed _to, uint256 indexed _value, bytes _data);

    // A setting to generate ERC20 Transfer events along with ERC223 Transfer events.
    bool public compatibilityMode = true;

    function disableCompatibility() public {
        if (compatibilityMode) { compatibilityMode = false; }
    }

	function balanceOf(address _tokenOwner) public constant returns (uint balance) {
        balance = balances[_tokenOwner];
    }

	function allowance(address _tokenOwner, address _spender) public constant returns (uint remaining) {
        remaining = allowed[_tokenOwner][_spender];
    }

	function approve(address _spender, uint _tokens) public returns (bool success) {
        require((allowed[msg.sender][_spender] == 0) || (_tokens == 0));

        allowed[msg.sender][_spender] = _tokens;
        Approval(msg.sender, _spender, _tokens);
        success = true;
    }

	// ERC20 transfers, backwards compatilibity
	function transfer(address _to, uint _tokens) onlyPayloadSize(2 * 32) public returns (bool success);
	function transferFrom(address _from, address _to, uint _tokens) public returns (bool success);

	// ERC223 transfers
	function transfer(address _to, uint _tokens, bytes _data) public returns (bool);
	function transferFrom(address _from, address _to, uint _tokens, bytes _data) public returns (bool success);

    modifier onlyPayloadSize(uint _size) {
        require( msg.data.length >= _size + 4 );
        _;
    }
}
