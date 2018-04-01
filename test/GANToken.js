const units = require('ethereumjs-units');
const BigNumber = require('bignumber.js');
const GanToken = artifacts.require('../contracts/AnimeFace.sol');
contract('GanToken', function(accounts) {

  it("should put 0 GanTokens in the first account", async () => {
    let instance = await GanToken.deployed();
    let balance = await instance.balanceOf.call(accounts[0]);

    assert.equal(balance.valueOf(), 0, "0 wasn't in the first account");
  });

  it("should be 1 GanToken in the first account after a page", async () => {
    let instance = await GanToken.deployed();
    await instance.newGanToken('940294023950239442343');
    let balance = await instance.balanceOf.call(accounts[0]);
    
    assert.equal(balance.valueOf(), 1, "1 wasn't in the first account");
  });

  it("should revert payment if an address is claiming the same id twice", async () => {
    let instance = await GanToken.deployed();
    let errorMessage;
    
    try {
      await instance.newGanToken('940294023950239442343');
    } catch (err) {
      errorMessage = err.message;
    }
    let balance = await instance.balanceOf.call(accounts[0]);
    
    assert.equal(errorMessage, 'VM Exception while processing transaction: revert', 'Did not revert the payment');
  });

  it("should be 2 GanTokens for this account", async () => {
    let instance = await GanToken.deployed();
    await instance.newGanToken('134535242323950239442343');
    let balance = await instance.balanceOf.call(accounts[0]);
    
    assert.equal(balance.valueOf(), 2, "2 wasn't in the first account");
  });

  it("should be the owner of the `134535242323950239442343` GanToken", async () => {
    let instance = await GanToken.deployed();
    let owner = await instance.ownerOf('134535242323950239442343');
      
    assert.equal(owner, accounts[0], accounts[0] + " wasn't the owner");
  });

  it("should own `134535242323950239442343` and `940294023950239442343` GanTokens", async () => {
    let instance = await GanToken.deployed();
    let tokens = await instance.tokensOfOwner(accounts[0]);

    assert.equal(tokens[0].c.join(''), '940294023950239442343', '940294023950239442343' + " owned by the account");
    assert.equal(tokens[1].c.join(''), '134535242323950239442343', '134535242323950239442343' + " owned by the account");
  });

  it("should have a total supply of 2", async () => {
    let instance = await GanToken.deployed();
    let supply = await instance.totalSupply();

    assert.equal(supply.valueOf(), 2, "the token supply was not 2 it was " + supply.valueOf());
  });

  it("should be able to approve another account to take token", async () => {
    let instance = await GanToken.deployed();
    let supply = await instance.approve(accounts[1], '940294023950239442343');
    let approvedAddress = await instance.getApproved('940294023950239442343');
    assert.equal(approvedAddress, accounts[1]);
  });

  it("should trasfer one token to another", async () => {
    let instance = await GanToken.deployed();
    await instance.transferFrom(accounts[0], accounts[1], '940294023950239442343', { from: accounts[1] });
    let tokens = await instance.tokensOfOwner(accounts[1]);

    assert.equal(tokens[0], '940294023950239442343', '940294023950239442343' + " owned by the account");
  });

  it("should be able to offer a token for sale", async () => {
    let instance = await GanToken.deployed();
    await instance.offerFaceForSale('134535242323950239442343', units.convert(1.88, 'eth', 'wei'), { from: accounts[0] });
    const saleData = await instance.getSaleData('134535242323950239442343');

    assert.equal(saleData[0], true);
  });

  it("should be able to remove sale", async () => {
    let instance = await GanToken.deployed();
    await instance.faceNoLongerForSale('134535242323950239442343', { from: accounts[0] });
    const saleData = await instance.getSaleData('134535242323950239442343');

    assert.equal(saleData[0], false);
  });


  it("should be able to remove sale", async () => {
    let instance = await GanToken.deployed();
    await instance.faceNoLongerForSale('134535242323950239442343', { from: accounts[0] });
    const saleData = await instance.getSaleData('134535242323950239442343');

    assert.equal(saleData[0], false);
  });


  it("should be able to offer sale to a specific address", async () => {
    let instance = await GanToken.deployed();
    await instance.offerFaceForSaleToAddress('134535242323950239442343', accounts[1], units.convert(1, 'eth', 'wei'), { from: accounts[0] });
    const saleData = await instance.getSaleData('134535242323950239442343');

    assert.equal(saleData[0], true);
    assert.equal(saleData[3], accounts[1]);
  });

  it("should revert transation if it is not the offer price", async () => {
    let instance = await GanToken.deployed();
    try {
      await instance.buyGanToken('134535242323950239442343', { from: accounts[1], value: units.convert(10, 'eth', 'wei'), gas: 1000000 });
    } catch (err) {
      errorMessage = err.message;
    }
    assert.equal(errorMessage, 'VM Exception while processing transaction: revert');
  });

  it("should be able to buy token", async () => {
    let instance = await GanToken.deployed();
    await instance.buyGanToken('134535242323950239442343', { from: accounts[1], value: units.convert(1, 'eth', 'wei'), gas: 1000000 });
    const saleData = await instance.getSaleData('134535242323950239442343');

    assert.equal(saleData[0], false);
    assert.equal(saleData[3], 0x0);
  });

  it("should show the seller has ether to withdraw", async () => {
    let instance = await GanToken.deployed();
    let pendingAmount = await instance.pendingWithdrawals.call(accounts[0]);

    assert.equal(pendingAmount, units.convert(1, 'eth', 'wei'));
  });

  it("should be able to withdraw funds", async () => {
    let instance = await GanToken.deployed();
    const balanceBeforeWithdraw = web3.fromWei(web3.eth.getBalance(accounts[0]));
    await instance.withdraw();
    const balanceAfterWithdraw = web3.fromWei(web3.eth.getBalance(accounts[0]));
    const diff = balanceAfterWithdraw.valueOf() - balanceBeforeWithdraw.valueOf();

    assert.equal(diff.toFixed(2), 1.00);
  });


  it("should be 2 GanToken in account 2", async () => {
    let instance = await GanToken.deployed();
    let balance = await instance.balanceOf.call(accounts[1]);

    assert.equal(balance.valueOf(), 2, "2 GanTokens were not in account2");
  });

  it("should be able to enter a bid for a GanToken", async () => {
    let instance = await GanToken.deployed();
    await instance.enterBidForGanToken('940294023950239442343', { from: accounts[0], value:  units.convert(1, 'eth', 'wei'), gas: 1000000 });
    const bidData = await instance.getBidData('940294023950239442343');

    assert.equal(bidData[0], true);

  });

  it("should be able to accept a bid", async () => {
    let instance = await GanToken.deployed();

    await instance.acceptBid('940294023950239442343', 1e18, { from: accounts[1], value: 0, gas: 1000000 });
    const bidData = await instance.getBidData('940294023950239442343');
    let owner = await instance.ownerOf('940294023950239442343');

    assert.equal(bidData[0], false);
    assert.equal(owner, accounts[0], accounts[0] + " wasn't the owner");
  });

  it("should be able to withdraw a bid", async () => {
    let instance = await GanToken.deployed();
    const balanceBeforeWithdraw = web3.fromWei(web3.eth.getBalance(accounts[0]));
    await instance.enterBidForGanToken('134535242323950239442343', { from: accounts[0], value:  units.convert(1, 'eth', 'wei'), gas: 1000000 });
    await instance.withdrawBid('134535242323950239442343', { from: accounts[0], value: 0, gas: 1000000 });
    const balanceAfterWithdraw = web3.fromWei(web3.eth.getBalance(accounts[0]));
    const diff = balanceAfterWithdraw.valueOf() - balanceBeforeWithdraw.valueOf();
    const bidData = await instance.getBidData('134535242323950239442343');
    const owner = await instance.ownerOf('134535242323950239442343');

    assert.equal(diff.toFixed(0), 0);
    assert.equal(bidData[0], false);
    assert.equal(owner, accounts[1], accounts[1] + " wasn't the owner");

  });

  it("should be able to withdraw bid funds", async () => {
    let instance = await GanToken.deployed();
    const balanceBeforeWithdraw = web3.fromWei(web3.eth.getBalance(accounts[1]));
    await instance.withdraw({ from: accounts[1] });
    const balanceAfterWithdraw = web3.fromWei(web3.eth.getBalance(accounts[1]));
    const diff = balanceAfterWithdraw.valueOf() - balanceBeforeWithdraw.valueOf();

    assert.equal(diff.toFixed(2), 1.00);
  });


});


