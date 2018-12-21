var Vesting = artifacts.require("Vesting");
var Token = artifacts.require("OPUCoin");
const assertRevert = require("./helpers/assertRevert");

contract("Vesting", accounts => {
  let vesting;
  let token;
  const owner = accounts[0];
  const founders = accounts[1];
  beforeEach(async () => {
    token = await Token.new({ from: owner });
    vesting = await Vesting.new(token.address, founders, { from: owner });
  });

  it("Successful initialization", async () => {
    var tokens = await vesting.token();
    assert.equal(tokens, token.address);
  });

  it("Initialize vesting", async () => {
    try {
      await vesting.initializeVesting(accounts[2], 100, { from: founders });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }

    await vesting.initializeVesting(accounts[2], 100, { from: owner });

    var tokensRemaining = await vesting.tokensRemainingInHolding.call(accounts[2]);
    assert.equal(tokensRemaining, 100);
  });

  it("Finalize vesting", async () => {
    await vesting.finalizeVestingAllocation(10, { from: owner });

    try {
      await vesting.finalizeVestingAllocation(10, { from: founders });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not initialize vesting after finalizing it", async () => {
    await vesting.finalizeVestingAllocation(10, { from: owner });
    
    try {
      await vesting.initializeVesting(accounts[2], 100, { from: owner });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Non-founder claiming tokens", async () => {
    await vesting.initializeVesting(accounts[2], 100, { from: owner });

    await vesting.finalizeVestingAllocation(20);

    await web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [86400 * 30 * 2], // 86400 seconds in a day
        id: new Date().getTime()
      },
      () => {}
    );

    await token.mint(vesting.address, 100);

    await vesting.claimTokens({ from: accounts[2] });

    var tokens = await token.balanceOf.call(accounts[2]);
    assert.equal(tokens, 20);
  });

  it("Non-founder trying to claim tokens twice for the same batch", async () => {
    await vesting.initializeVesting(accounts[2], 100, { from: owner });

    await vesting.finalizeVestingAllocation(20);

    await web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [86400 * 30 * 1], // 86400 seconds in a day
        id: new Date().getTime()
      },
      () => {}
    );

    await token.mint(vesting.address, 100);

    await vesting.claimTokens({ from: accounts[2] });

    var tokens = await token.balanceOf.call(accounts[2]);
    assert.equal(tokens, 10);

    try {
      await vesting.claimTokens({ from: accounts[2] });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Random account trying to claim tokens", async () => {
    await vesting.initializeVesting(accounts[2], 100, { from: owner });

    await vesting.finalizeVestingAllocation(20);

    await web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [86400 * 30 * 1], // 86400 seconds in a day
        id: new Date().getTime()
      },
      () => {}
    );

    await token.mint(vesting.address, 100);

    try {
      await vesting.claimTokens({ from: accounts[3] });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Non-founder trying to claim tokens before vesting is finalized", async () => {
    await vesting.initializeVesting(accounts[2], 100, { from: owner });

    await web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [86400 * 30 * 1], // 86400 seconds in a day
        id: new Date().getTime()
      },
      () => {}
    );

    await token.mint(vesting.address, 100);

    try {
      await vesting.claimTokens({ from: accounts[2] });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  // it("Founder claiming tokens", async () => {
  //   await vesting.initializeVesting(founders, 100, { from: owner });

  //   await vesting.finalizeVestingAllocation(20);

  //   try {
  //     await vesting.claimTokens({ from: founders });
  //     assert.fail("should have thrown before");
  //   } catch (error) {
  //     assertRevert(error);
  //   }

  //   await web3.currentProvider.sendAsync(
  //     {
  //       jsonrpc: "2.0",
  //       method: "evm_increaseTime",
  //       params: [86400 * 30 * 13], // 86400 seconds in a day
  //       id: new Date().getTime()
  //     },
  //     () => {}
  //   );

  //   await token.mint(vesting.address, 100);

  //   await web3.currentProvider.sendAsync(
  //     {
  //       jsonrpc: "2.0",
  //       method: "evm_increaseTime",
  //       params: [86400 * 5], // 86400 seconds in a day
  //       id: new Date().getTime()
  //     },
  //     () => {}
  //   );

  //   await vesting.claimTokens({ from: founders });

  //   var tokens = await token.balanceOf.call(founders);
  //   assert.equal(tokens, 8);
  // });
});
