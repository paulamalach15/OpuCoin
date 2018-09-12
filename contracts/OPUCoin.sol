pragma solidity 0.4.24;

import "./Token/MintableToken.sol";

contract OPUCoin is MintableToken {
    string constant public symbol = "OPU";
    string constant public name = "Opu Coin";
    uint8 constant public decimals = 18;

    // -------------------------------------------
	// Public functions
    // -------------------------------------------
    constructor() public { }
}
