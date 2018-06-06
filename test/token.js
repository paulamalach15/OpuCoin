
const web3 = global.web3;

const OPUCoin = artifacts.require("./OPUCoin.sol");

var token;

contract("OPUCoin test", async function(accounts) {
    const [manager, backend, founders, partners, coldStorage, holding] = accounts;

    it("token deploys", async () => {
        token = await OPUCoin.new({from: manager});
        assert.isOk(token && token.address, "should have valid address");
    });

    it("initial minting", async () => {
        await token.initialMinting(backend, {from: manager});
        let backendTokens = Number(await token.balanceOf(backend));
        assert.equal(backendTokens, 12 * 1e9 * 1e18, "wrong number of tokens");
    });

    it("transfer to wallet", async () => {
        await token.transfer(manager, 30 * 1e18, {from: backend});
        managerTokens = Number(await token.balanceOf(manager));
        assert.equal(managerTokens, 30 * 1e18, "wrong number of tokens");
    });

    it("transfer to contract with no tokenFallback should fail", async () => {
        try {
            await token.transfer(token.address, 30 * 1e18, {from: backend});
            assert.fail();
        } catch(err) {
            z = err.message.search("invalid opcode") >= 0;
            assert(z, "contract should reject token transfer");
        }

        let contractTokens = Number(await token.balanceOf(token.address));
        assert.equal(contractTokens, 0, "wrong number of tokens");
    });
});
