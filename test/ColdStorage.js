var ColdStorage = artifacts.require("ColdStorage");
var Token = artifacts.require("OPUCoin");
const assertRevert = require("./helpers/assertRevert");

contract("ColdStorage", accounts => {
  let coldStorage;
  let token;
  const owner = accounts[0];
  const founders = accounts[1];
  beforeEach(async () => {
    token = await Token.new({ from: owner });
    coldStorage = await ColdStorage.new(token.address, { from: owner });
  });

  it("Successful initialization", async () => {
    var tokens = await coldStorage.token();
    assert.equal(tokens, token.address);
  });

  it("Initialize holding", async () => {
    await token.mint(coldStorage.address, 100);

    await coldStorage.initializeHolding(founders, { from: owner });

    var initializeStorage = await coldStorage.storageInitialized.call();
    assert.equal(initializeStorage, true);

    var founder = await coldStorage.founders.call();
    assert.equal(founder,founders);
  });

  it("Should not initialize holding if token balance is 0", async () => {
    try {
      await coldStorage.initializeHolding(founders, { from: owner });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }
  });

  it("Should not initialize holding twice", async () => {
    await token.mint(coldStorage.address, 100);

    await coldStorage.initializeHolding(founders, { from: owner });

    try {
      await coldStorage.initializeHolding(accounts[7], { from: owner });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }    
  });

  it("Claiming tokens", async () => {
    await token.mint(coldStorage.address, 100);

    await coldStorage.initializeHolding(founders, { from: owner });

    await web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [86400 * 366 * 2], // 86400 seconds in a day
        id: new Date().getTime()
      },
      () => {}
    );

    await coldStorage.claimTokens({ from: founders });

    var balance = await token.balanceOf.call(founders);
    assert.equal(balance, 100);
  });

  it("Should not be able to claim tokens before the lockup period ends", async () => {
    await token.mint(coldStorage.address, 100);

    await coldStorage.initializeHolding(founders, { from: owner });

    await web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [86400 * 364 * 2], // 86400 seconds in a day
        id: new Date().getTime()
      },
      () => {}
    );

    try {
      await coldStorage.claimTokens({ from: founders });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }

    var balance = await token.balanceOf.call(founders);
    assert.equal(balance, 0);
  });

  it("Should not be able to claim tokens if not the founders' account", async () => {
    await token.mint(coldStorage.address, 100);

    await coldStorage.initializeHolding(founders, { from: owner });

    await web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [86400 * 366 * 2], // 86400 seconds in a day
        id: new Date().getTime()
      },
      () => {}
    );

    try {
      await coldStorage.claimTokens({ from: accounts[7] });
      assert.fail("should have thrown before");
    } catch (error) {
      assertRevert(error);
    }

    var balance = await token.balanceOf.call(founders);
    assert.equal(balance, 0);
  });
});
