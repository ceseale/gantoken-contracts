/* global artifacts */
const Migrations = artifacts.require('./AnimeFace.sol');

module.exports = (deployer) => {
  deployer.deploy(Migrations);
};
