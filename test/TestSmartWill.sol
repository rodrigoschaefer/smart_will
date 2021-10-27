// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SmartWill.sol";

contract TestSmartWill {

    // Truffle will send the TestContract one Ether after deploying the contract.
    uint public initialBalance = 1 ether;

    SmartWill smartWill = SmartWill(DeployedAddresses.SmartWill());

    address payable expectedOwner = payable(address(this));
    address payable recipient = payable(address(0xfd2Cc0AE059F54b1917Ac41a46C496e23f73cD15));

    uint createdWillId;
    uint willValue = 10000;
    
    function beforeAll () public {}

    function testGetMaxWillsNumber() public {
        uint maxWills = smartWill.getMaxWillCount();
        Assert.equal(maxWills, 10, "Max vaults should be 10");
    }

    function testCreateWill() public {
        createdWillId = smartWill.createWill{ value: willValue }(block.timestamp - 1 hours, expectedOwner);
        Assert.isNotZero(createdWillId, "Id should be greater than zero");
    }

    function testGetWill() public {
        SmartWill.Will memory will = smartWill.getWill(createdWillId);
        Assert.equal(createdWillId, will.id, "Ids should be equal");
        Assert.equal(willValue, will.ammount, "Will value should be equal");
    }
    
}

