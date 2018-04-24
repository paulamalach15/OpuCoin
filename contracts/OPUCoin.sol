pragma solidity ^0.4.18;

import "./interfaces/ContractReceiver.sol";
import "./Token.sol";

// Omitting SafeMath, because all the checks are implicit in the fixed total token supply.
contract OPUCoin is Token {
    string constant public symbol = "OPU";
    string constant public name = "Opu Coin";
    uint8 constant public decimals = 18;
    uint public totalSupply = 0;
    address public manager;

    mapping (address => uint) public balances;
    mapping (address => mapping (address => uint)) public allowed;

    // A setting to generate ERC20 Transfer events along with ERC223 Transfer events.
    bool public compatibilityMode = true;

    // -------------------------------------------
	// Events
    // -------------------------------------------
	event Approval(address indexed _tokenOwner, address indexed _spender, uint _tokens);
	// ERC20 Transfer event, added for compatibility, can be disabled once and forever
	event Transfer(address indexed _from, address indexed _to, uint _tokens);
	// ERC223 Transfer event
	event Transfer(address indexed _from, address indexed _to, uint256 indexed _value, bytes _data);

    // -------------------------------------------
	// Public functions
    // -------------------------------------------
    function OPUCoin() public {
        manager = msg.sender;
    }

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

    /**
     * @dev A safer and recommended "Compare and set" approve method.
     * @param _spender The address geting the stipend.
     * @param _currentValue The unspend stipend that is expected at the time of sending the transaction
     * @param _tokens The new stipend which will only be set if the expected one matches the contract state.
     */
    function approve(address _spender, uint _currentValue, uint _tokens) public returns (bool success) {
        if (allowed[msg.sender][_spender] == _currentValue) {
            allowed[msg.sender][_spender] = _tokens;
            Approval(msg.sender, _spender, _tokens);
            success = true;
        } else {
            success = false;
        }
    }

    /**
     * @dev ERC20-compatible transfer
     */
	function transfer(address _to, uint _tokens) onlyPayloadSize(2 * 32) public returns (bool success) {
        bytes memory empty;
        success = transfer(_to, _tokens, empty);
    }

    /**
     * @dev ERC20-compatible transferFrom
     */
    function transferFrom(address _from, address _to, uint _tokens) public returns (bool success) {
        bytes memory empty;
        success = transferFrom(_from, _to, _tokens, empty);
    }


	// ERC223 transfers
    /**
     * @dev ERC223 transfer
     */
	function transfer(address _to, uint _tokens, bytes _data) public returns (bool success) {
        if (balances[msg.sender] >= _tokens) {

            balances[msg.sender] -= _tokens;
            balances[_to]        += _tokens;

            if ( isContract(_to) ) {
                ContractReceiver receiver = ContractReceiver(_to);
                receiver.tokenFallback(msg.sender, _tokens, _data);
            }

            // Emit a ERC223 transfer event. If compatibility is enabled, emit an ERC20 transfer event as well.
            if (compatibilityMode) { Transfer(msg.sender, _to, _tokens); }
            Transfer(msg.sender, _to, _tokens, _data);

            success = true;
        } else {
            success = false;
        }
    }

    /**
     * @dev ERC223 transferFrom
     */
	function transferFrom(address _from, address _to, uint _tokens, bytes _data) public returns (bool success) {
        if (    (balances[_from]            >= _tokens) 
             && (allowed[_from][msg.sender] >= _tokens) ) {

            balances[_from] -= _tokens;
            balances[_to]   += _tokens;

            if ( isContract(_to) ) {
                ContractReceiver receiver = ContractReceiver(_to);
                receiver.tokenFallback(_from, _tokens, _data);
            }

            // Emit a ERC223 transfer event. If compatibility is enabled, emit an ERC20 transfer event as well.
            if (compatibilityMode) { Transfer(msg.sender, _to, _tokens); }
            Transfer(_from, _to, _tokens, _data); 

            success = true;
        } else {
            success = false;
        }
    }

    /**
     * @dev ERC223 transfer with custom function called instead of tokenFallback
     */
	function transfer(address _to, uint _tokens, bytes _data, string _customFallback) public returns (bool success) {
        if (balances[msg.sender] >= _tokens) {

            balances[msg.sender] -= _tokens;
            balances[_to]        += _tokens;

            if ( isContract(_to) ) {
                    assert(_to.call.value(0)(bytes4(keccak256(_customFallback)), msg.sender, _tokens, _data));
            }

            // Emit a ERC223 transfer event. If compatibility is enabled, emit an ERC20 transfer event as well.
            if (compatibilityMode) { Transfer(msg.sender, _to, _tokens); }
            Transfer(msg.sender, _to, _tokens, _data);

            success = true;
        } else {
            success = false;
        }
    }

    /**
     * @dev ERC223 transferFrom with custom function called instead of tokenFallback
     */
	function transferFrom(address _from, address _to, uint _tokens, bytes _data, string _customFallback) public returns (bool success) {
        if (    (balances[_from]             >= _tokens) 
             && (allowed[_from][msg.sender] >= _tokens) ) {

            balances[_from] -= _tokens;
            balances[_to]   += _tokens;

            if ( isContract(_to) ) {
                assert(_to.call.value(0)(bytes4(keccak256(_customFallback)), msg.sender, _tokens, _data));
            }

            // Emit a ERC223 transfer event. If compatibility is enabled, emit an ERC20 transfer event as well.
            if (compatibilityMode) { Transfer(msg.sender, _to, _tokens); }
            Transfer(_from, _to, _tokens, _data); 

            success = true;
        } else {
            success = false;
        }
    }

    // -------------------------------------------
	// Privileged functions
    // -------------------------------------------
    function initialMinting(address _allocation) public {
        require( msg.sender == manager );
        require( _allocation != 0x0 );

        uint newSupply = 12 * 1e9 * 1e18;
        balances[_allocation] = newSupply;
        totalSupply = newSupply;

        bytes memory empty;
        if (isContract(_allocation)) {
            ContractReceiver receiver = ContractReceiver(_allocation);
            receiver.tokenFallback(0x0, newSupply, empty);
        }

        Transfer(0x0, _allocation, newSupply);
        Transfer(0x0, _allocation, newSupply, empty); 
    }

    // -------------------------------------------
	// Private functions
    // -------------------------------------------
    // ERC223 helper function to check whether an address holds a contract
    //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
    function isContract(address _addr) private view returns (bool) {
        uint length;
        assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        return (length>0);
    }

    modifier onlyPayloadSize(uint _size) {
        require( msg.data.length >= _size + 4 );
        _;
    }
}
