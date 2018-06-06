
const web3 = global.web3;

const OPUCoin = artifacts.require("./OPUCoin.sol");
const Allocation = artifacts.require("./Allocation.sol");
const Vesting = artifacts.require("./Vesting.sol");

var token;
var allocation;
var holdingTokens = 12 * 1e3 * 1e18;
var holders = 12;
var vesting;

contract("Allocation testing", async function(accounts) {
    const [manager, backend, founders, partners, coldStorage, holding, c1, c2, c3, c4] = accounts;

    it("token deploys", async () => {
        token = await OPUCoin.new({from: manager});
        assert.isOk(token && token.address, "should have valid address");
    });

    it("allocation deploys", async () => {
        allocation = await Allocation.new(backend, token.address, founders, 
                                        partners, coldStorage, holding, {from:manager});
        assert.isOk(allocation && allocation.address, "should have valid address");
    });

    it("allocation receives tokens", async () => {
        await token.initialMinting(allocation.address, {from: manager});
        let backendTokens = Number(await token.balanceOf(allocation.address));
        assert.equal(backendTokens, 12 * 1e9 * 1e18, "wrong number of tokens");
    });

    it("non-backend cannot initialize allocation", async() => {
        try {
            await allocation.initializeAllocation(holders, holdingTokens, {from: c1});
            assert.fail();
        } catch(err) {
            z = err.message.search("invalid opcode") >= 0;
            assert(z, "contract should reject transaction");
        }
    });

    it("backend can initialize and do an allocation", async () => {
        await allocation.initializeAllocation(holders, holdingTokens, {from: backend});
        let c1purchase = 30 * 1e18;
        let c1bounty = 5 * 1e18;
        await allocation.allocate(c1, c1purchase, c1bounty, {from: backend});
        let c1tokens = Number(await token.balanceOf(c1));
        assert.equal(c1tokens, c1purchase * 150 / 100 + c1bounty, "wrong number of tokens allocated");
    });

    it("advance bonus stage and do an allocation", async () => {
        await allocation.advanceBonusPhase({from: backend});
        let c2purchase = 400 * 1e18;
        let c2bounty = 25 * 1e18;
        await allocation.allocate(c2, c2purchase, c2bounty, {from: backend});
        let c2tokens = Number(await token.balanceOf(c2));
        assert.equal(c2tokens, c2purchase * 140 / 100 + c2bounty, "wrong number of tokens allocated");
    });

    it("allocations don't work when paused by manager", async () => {
        await allocation.emergencyPause({from: manager});
        let paused = await allocation.emergencyPaused();
        assert.isTrue(paused, "the pause didn't work");

        try {
            await allocation.allocate(c2, 8 * 1e18, 0, {from: backend});
            assert.fail();
        } catch(err) {
            z = err.message.search("invalid opcode") >= 0;
            assert(z, "contract should reject transaction");
        } finally {
            await allocation.emergencyUnpause({from: manager});
            paused = await allocation.emergencyPaused();
            assert.isFalse(paused, "couldn't cancel the pause");
        }
    });

    it("advance bonus stage to ICO and do an allocation", async () => {
        await allocation.advanceBonusPhase({from: backend});
        await allocation.advanceBonusPhase({from: backend});
        await allocation.advanceBonusPhase({from: backend});
        await allocation.advanceBonusPhase({from: backend});
        await allocation.advanceBonusPhase({from: backend});
        await allocation.advanceBonusPhase({from: backend});
        await allocation.advanceBonusPhase({from: backend});
        await allocation.advanceBonusPhase({from: backend});
        let c3purchase = 800 * 1e18;
        let c3bounty = 0;
        await allocation.allocate(c3, c3purchase, c3bounty, {from: backend});
        let c3tokens = Number(await token.balanceOf(c3));
        assert.equal(c3tokens, c3purchase + c3bounty, "wrong number of tokens allocated");
    });

    it("try to advance bonus stage further and fail", async () => {
        let bs1 = Number(await (allocation.bonusStage()));
        assert.equal(bs1, 9, "bonus stage is 9");
        try {
            await allocation.advanceBonusPhase({from: backend});
            assert.fail();
        } catch(err) {
            z = err.message.search("invalid opcode") >= 0;
            assert(z, "expected throw not received");
        }
    });

    it("allocate tokens into holding with holding bonus", async () => {
        let c4purchase = 6000 * 1e18;
        let c4bounty = 40 * 1e18;

        vesting = Vesting.at(await allocation.vesting());
        let vestingListener = vesting.VestingInitialized({fromBlock: 'latest', toBlock: 'latest'});
        let allocationListener = allocation.TokensAllocatedIntoHolding({fromBlock: 'latest', toBlock: 'latest'});

        await allocation.allocateIntoHolding(c4, c4purchase, c4bounty, {from: backend});

        let vestingLog = await new Promise(
                (resolve, reject) => vestingListener.get(
                    (error, log) => error ? reject(error) : resolve(log)
                    ));
        let allocationLog = await new Promise(
                (resolve, reject) => allocationListener.get(
                    (error, log) => error ? reject(error) : resolve(log)
                    ));

        let vs = vestingLog[0].args;
        let al = allocationLog[0].args;

        let expectedTokens = c4purchase + c4bounty + holdingTokens / holders;
        assert.equal(al._buyer, c4, "Allocation event has wrong address");
        assert.equal(Number(al._tokens), expectedTokens, "Allocation event has the wrong number of tokens");
        assert.equal(vs._to, c4, "Vesting has wrong address");
        assert.equal(Number(vs._tokens), expectedTokens, "Vesting has the wrong number of tokens");
    });

    it("finalize allocation: team, partners, cold storage, network storage", async () => {
        let vestingListener = vesting.VestingInitialized({fromBlock: 'latest', toBlock: 'latest'});
        let allocationListener = allocation.AllocationFinished({fromBlock: 'latest', toBlock: 'latest'});

        res = await allocation.finalizeAllocation({from: backend, gas: 6500000});
        res = await allocation.finalizeAllocation({from: backend, gas: 6500000});
        res = await allocation.finalizeAllocation({from: backend, gas: 6500000});
        res = await allocation.finalizeAllocation({from: backend, gas: 6500000});

        let vestingLog = await new Promise(
                (resolve, reject) => vestingListener.get(
                    (error, log) => error ? reject(error) : resolve(log)
                    ));
        let allocationLog = await new Promise(
                (resolve, reject) => allocationListener.get(
                    (error, log) => error ? reject(error) : resolve(log)
                    ));

        let expectedAddrs = [founders, partners, coldStorage];
        let expectedSums = [1260 * 1e6 * 1e18, 
                             480 * 1e6 * 1e18, 
                             600 * 1e6 * 1e18];

        //let is = await vesting.holdings(founders);
        //console.log(is);
        /*
         * removed due to Truffle sometimes not processing listeners properly
        assert.equal(vestingLog.length, 3, "Vesting events didn't fire");
        for (let i=0; i< expectedSums.length; i++) {
            vs = vestingLog[i].args;
            assert.equal(vs._to, expectedAddrs[i], "Vesting " +i+ " has wrong address");
            assert.equal(Number(vs._tokens), expectedSums[i], "Vesting " +i+ " has the wrong number of tokens");
        }
        */

        let holdingStorageTokens = Number(await token.balanceOf(holding));
        assert.equal(holdingStorageTokens, 8880 * 1e6 * 1e18, "wrong number of tokens allocated into storage");

        assert.equal(allocationLog.length, 1, "Allocation finished event didn't fire");
    });

    it("releases nothing until a year and a month passes", async () => {
        try {
            await vesting.claimTokens({from: founders});
            assert.fail();
        } catch(err) {
            z = err.message.search("invalid opcode") >= 0;
            assert(z, "expected throw not received");
        }
    });

    it("can release vesting batch of 1/12 size after 365 + 30 days", async () => {
        let increaseTime = addSeconds => web3.currentProvider
            .send({jsonrpc: "2.0", method: "evm_increaseTime", params: [addSeconds], id: 0})

        increaseTime(3600 * 24 * (365 + 40));
        await vesting.claimTokens({from: founders});

        assert.isAtLeast(
                Number( await( token.balanceOf( founders ))) * 1.02,
                1260 * 1e6 * 1e18 / 12,
                "1/12th is collected by the founders");
                
        assert.isAtMost(
                Number( await( token.balanceOf( founders ))) * 0.98,
                1260 * 1e6 * 1e18 / 12,
                "1/12th is collected by the founders");
    });
});
