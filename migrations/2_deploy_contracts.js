const SmartWill = artifacts.require("SmartWill");

module.exports = function (deployer) {
    deployer.deploy(SmartWill);
};