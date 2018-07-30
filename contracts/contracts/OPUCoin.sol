pragma solidity ^0.4.18;

import "./Token/MintableToken.sol";

contract OPUCoin is MintableToken {
    string constant public symbol = "OPU";
    string constant public name = "Opu Coin";
    uint8 constant public decimals = 18;
    uint public totalSupply = 0;

    // -------------------------------------------
	// Public functions
    // -------------------------------------------
    constructor() public { }
}
