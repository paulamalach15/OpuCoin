var Allocation = artifacts.require("Allocation");
const assertRevert = require("./helpers/assertRevert");

contract("Allocation", accounts => {
  let allocation;
  const owner = accounts[0];
  const backend = accounts[1];
  const team = accounts[2];
  const partners = accounts[3];
  const storage = accounts[4];

  const million = 1e6 * 1e18;
  beforeEach(async () => {
    allocation = await Allocation.new(backend, team, partners, storage, {
      from: owner
    });
  });

  it("Emergency pause", async () => {
    await allocation.emergencyPause();

    var paused = await allocation.emergencyPaused.call();
    assert.equal(paused, true);
  });

  it("Only owner should be able to call emergency pause", async () => {
    try {
      await allocation.emergencyPause({ from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }

    var paused = await allocation.emergencyPaused.call();
    assert.equal(paused, false);
  });

  it("Should not be able to call emergency pause if already paused", async () => {
    await allocation.emergencyPause();

    try {
      await allocation.emergencyPause();
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }

    var paused = await allocation.emergencyPaused.call();
    assert.equal(paused, true);
  });

  it("Emergency unpause", async () => {
    await allocation.emergencyPause();
    await allocation.emergencyUnpause();

    var paused = await allocation.emergencyPaused.call();
    assert.equal(paused, false);
  });

  it("Only owner should be able to call emergency unpause", async () => {
    await allocation.emergencyPause();

    try {
      await allocation.emergencyUnpause({ from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }

    var paused = await allocation.emergencyPaused.call();
    assert.equal(paused, true);
  });

  it("Should not be able to call emergency unpause if already unpaused", async () => {
    await allocation.emergencyPause();
    await allocation.emergencyUnpause();

    try {
      await allocation.emergencyUnpause();
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }

    var paused = await allocation.emergencyPaused.call();
    assert.equal(paused, false);
  });

  it("Allocate", async () => {
    await allocation.allocate(accounts[7], 100, 100, { from: backend });
  });

  it("Only backend should be able to call allocate", async () => {
    try{
      await allocation.allocate(accounts[7], 100, 100, { from: owner });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not be able to call allocate when emergency paused", async () => {
    await allocation.emergencyPause();

    try{
      await allocation.allocate(accounts[7], 100, 100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not be able to allocate when buyer address is 0x0", async () => {
    try{
      await allocation.allocate(0x0, 100, 100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not be able to allocate when totalTokensSold is greater than ICO distribution", async () => {
    try{
      await allocation.allocate(accounts[7], (1350 * million + 10), 100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not be able to allocate when totalTokensRewarded is greater than Reward pool", async () => {
    try{
      await allocation.allocate(accounts[7], 100, (189 * million + 1), { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Finalize holding and team tokens", async () => {
    await allocation.finalizeHoldingAndTeamTokens(100, { from: backend });

    var finalized = await allocation.finalizedHoldingsAndTeamTokens.call();
    assert.equal(finalized, true);

    var mintFinished = await allocation.mintingFinished.call();
    assert.equal(mintFinished, true);
  });

  it("Should not be able to allocate after holding and team tokens are finalized", async () => {
    await allocation.allocate(accounts[7], 100, 100, { from: backend });
    await allocation.finalizeHoldingAndTeamTokens(100, { from: backend });
    
    try{
      await allocation.allocate(accounts[9], 100, 100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Only backend should be able to finalize holding and team tokens", async () => {
    try{
      await allocation.finalizeHoldingAndTeamTokens(100, { from: team });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not be able to finalize holding and team tokens when emergency paused", async () => {
    await allocation.emergencyPause();
    
    try{
      await allocation.finalizeHoldingAndTeamTokens(100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should be able to finalize holding and team tokens only once", async () => {
    await allocation.finalizeHoldingAndTeamTokens(100, { from: backend });
    
    try{
      await allocation.finalizeHoldingAndTeamTokens(100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Opt address into holding", async () => {
    const holder = accounts[3];
    await allocation.allocate(allocation.address, 100, 100, { from: backend });
    await allocation.optAddressIntoHolding(holder, 100, { from: backend });
  });

  it("Only backend should be able to call opt address into holding", async () => {
    const holder = accounts[3];
    await allocation.allocate(allocation.address, 100, 100, { from: backend });

    try {
      await allocation.optAddressIntoHolding(holder, 100, { from: team });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not execute opt address into holding after finalizing holding and team tokens", async () => {
    const holder = accounts[3];
    await allocation.allocate(allocation.address, 100, 100, { from: backend });
    await allocation.finalizeHoldingAndTeamTokens(100, { from: backend });

    try {
      await allocation.optAddressIntoHolding(holder, 100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Allocate into holding", async () => {
    await allocation.allocateIntoHolding(accounts[7], 100, 100, { from: backend });
  });

  it("Only backend can allocate into holding", async () => {
    try {
      await allocation.allocateIntoHolding(accounts[7], 100, 100, { from: team });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not allocate into holding when emergency paused", async () => {
    await allocation.emergencyPause();
    try {
      await allocation.allocateIntoHolding(accounts[7], 100, 100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not be able to allocate into holding when totalTokensSold is greater than ICO distribution", async () => {
    try{
      await allocation.allocateIntoHolding(accounts[7], (1350 * million + 1), 100, { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not be able to allocate into holding when totalTokensRewarded is greater than Reward pool", async () => {
    try{
      await allocation.allocateIntoHolding(accounts[7], 100, (189 * million + 1), { from: backend });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });
});