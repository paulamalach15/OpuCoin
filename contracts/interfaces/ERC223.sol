pragma solidity ^0.4.18;

interface ERC223 {
	function totalSupply() public constant returns (uint);
	function balanceOf(address _tokenOwner) public constant returns (uint balance);
	function allowance(address _tokenOwner, address _spender) public constant returns (uint remaining);
	function approve(address _spender, uint _tokens) public returns (bool success);
	function transfer(address _to, uint _tokens, bytes _data) public returns (bool);
	function transfer(address _to, uint _tokens, bytes _data, string _customFallback) public returns (bool);
	function transferFrom(address _from, address _to, uint _tokens, bytes _data) public returns (bool success);

	event Approval(address indexed _tokenOwner, address indexed _spender, uint _tokens);
	event Transfer(address indexed _from, address indexed _to, uint256 indexed _value, bytes _data);
}
