var LENDCO_Token = artifacts.require("./LENDCO_Token.sol");

module.exports = function(deployer) {
  deployer.deploy(LENDCO_Token);
};
