var KingsLoto = artifacts.require("./KingsLoto.sol");

module.exports = function(deployer) {
  deployer.deploy(KingsLoto, {gas: 3500000});
};
