/* global artifacts */
const Migrations = artifacts.require('./GanTokenMain.sol');

module.exports = (deployer) => {
  deployer.deploy(Migrations);
};
