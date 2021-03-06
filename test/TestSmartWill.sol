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
    address payable recipient = payable(address(0xfa67329C59457b31a58d797d3970d11c96Eb6702));

    uint createdWillId;
    uint willValue = 10000;

    event RedeemResult(int redeemed);

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
    
    function beforeAll () public {}

    function testGetMaxWillsNumber() public {
        uint maxWills = smartWill.getMaxWillCount();
        Assert.equal(maxWills, 10, "Max vaults should be 10");
    }

    function testCreateWill() public {
        createdWillId = smartWill.createWill{ value: willValue }(block.timestamp - 1 hours, expectedOwner);
        Assert.isNotZero(createdWillId, "Id should be greater than zero");
        SmartWill.Will memory will = smartWill.getWill(createdWillId);
        Assert.equal(will.id, createdWillId, "Id should be the one expected");
    }

    function testGetAllOwnerWills() public {
        SmartWill.Will[] memory wills = smartWill.getWillsByOwner(expectedOwner);
        Assert.equal(wills.length, 1, "Should have found a will");
    }

     function testGetAllRecipientWills() public {
        smartWill.createWill{ value: willValue }(block.timestamp - 1 hours, recipient);
        SmartWill.Will[] memory wills = smartWill.getWillsByRecipient(recipient);
        Assert.equal(wills.length, 1, "Should have found a will");
    }

    function testGetWill() public {
        SmartWill.Will memory will = smartWill.getWill(createdWillId);
        Assert.equal(createdWillId, will.id, "Ids should be equal");
        Assert.equal(willValue, will.ammount, "Will value should be equal");
    }

    function testRegisterActivy() public {
        smartWill.registerActivity(createdWillId);
        SmartWill.Will memory will = smartWill.getWill(createdWillId);
        Assert.equal(will.lastActivity,block.timestamp,"Last activity should be equal to current block timestamp");
    }

    function testRedeemWill() public {
        uint balance = address(this).balance;
        createdWillId = smartWill.createWill{ value: willValue }(block.timestamp - 1 hours, expectedOwner);
        uint newBalance = address(this).balance;
        Assert.equal(newBalance, balance - willValue, "Balance should have decreased");
        smartWill.redeemWill(createdWillId);
        newBalance = address(this).balance;
        Assert.equal(newBalance, balance, "Balance should be back to original");
        SmartWill.Will memory will = smartWill.getWill(createdWillId);
        Assert.equal(will.redeemed, true, "Will should be redeemed");
    }

    function testFailedRedeemByActivityWill() public {
        createdWillId = smartWill.createWill{ value: willValue }(block.timestamp - 1 hours, expectedOwner);
        smartWill.registerActivity(createdWillId);
        string memory errorMsg;
        try  smartWill.redeemWill(createdWillId) {
        } catch Error(string memory reason) {
            errorMsg = reason;
        }
        Assert.equal(errorMsg,'Inheritance needs to wait 6 months from last owner activity', 'Will should not be redeemed within the 180 days activity period');
    }

    function testRefundWill() public {
        uint originalBalance = address(this).balance;
        createdWillId = smartWill.createWill{ value: willValue }(block.timestamp - 1 hours, expectedOwner);
        uint createdWillBalance = address(this).balance;
        Assert.equal(createdWillBalance, originalBalance - willValue, "Balance should have decreased");
        smartWill.refundWill(createdWillId);
        uint refundedWillBalance = address(this).balance;
        Assert.isAbove(refundedWillBalance, createdWillBalance, "Balance should have increased");
        SmartWill.Will memory will = smartWill.getWill(createdWillId);
        Assert.equal(will.refunded,true, 'Will should be refunded');
    }

}

