// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

/**
 * @title SmartWill
 * @dev Time based resource transfers
 */
contract SmartWill {

    event WillCreated(address owner, uint id);
    event WillDeleted(address owner, uint id);
    event WillActivityRegistered(uint id, uint blockTime);
    event WillRedeemed(address recipient, uint id);

    uint constant maxWillCount = 10;

    struct Will {
        uint id;
        address owner;
        uint ammount;
        uint redemptionDate;
        uint lastActivity;
        address payable recipient;
    }

    uint currentId;

    mapping(address => Will[]) public willsByOwner;
    mapping(address => Will[]) public willsByRecipient;

    constructor() {
        currentId = 1;
    }

    function createWill(uint redemptionDate, address payable recipient) external payable returns (uint){
        Will[] storage wills = willsByOwner[msg.sender];
        // Check if maxWillCount reached
        require(wills.length < maxWillCount, "Maximum number of wills reached");
        currentId++;
        Will memory will = Will({
            id: currentId,
            owner: msg.sender,
            ammount: msg.value,
            redemptionDate: redemptionDate,
            recipient: recipient,
            lastActivity: 0
        });
        wills.push(will);
        willsByOwner[msg.sender] = wills;

        Will[] storage willsByRecipientList = willsByRecipient[recipient];
        require(willsByRecipientList.length < maxWillCount, "Maximum number of wills reached for this retriever");    
        willsByRecipientList.push(will);
        willsByRecipient[recipient] = willsByRecipientList;

        emit WillCreated(msg.sender,currentId);

        return currentId;
    }

    function getMaxWillCount() external pure returns (uint){
        return maxWillCount;
    }

    /**
     * @dev Get a will by id
     * @return w will
     */
    function getWill(uint id) external view returns (Will memory w){
        Will[] memory willsByOwnerList = willsByOwner[msg.sender];
        for (uint8 index = 0; index < willsByOwnerList.length; index++) {
            if(willsByOwnerList[index].id == id) {
               return willsByOwnerList[index];
            }
        }
        revert('Not found');
    }
    
    /**
     * @dev Deletes a will
     */
    function deleteWill(uint id) public returns (bool){
        Will[] storage willsByOwnerList = willsByOwner[msg.sender];
        require(
           willsByOwnerList.length > 0, "Will list not found"
        );
        Will memory will;
        for (uint8 index = 0; index < willsByOwnerList.length; index++) {
            if(willsByOwnerList[index].id == id) {
               will = willsByOwnerList[index];
               willsByOwnerList[index] = willsByOwnerList[willsByOwnerList.length-1];
               willsByOwnerList.pop();
               willsByOwner[msg.sender] = willsByOwnerList;
               break;
            }
        }
        if(will.id > 0){
                Will[] storage willsByRecipientList = willsByRecipient[will.recipient];
                for (uint8 index = 0; index < willsByRecipientList.length; index++) {
                    if(willsByRecipientList[index].id == id) {
                        will = willsByRecipientList[index];
                        willsByRecipientList[index] = willsByRecipientList[willsByRecipientList.length-1];
                        willsByRecipientList.pop();
                        willsByRecipient[will.recipient] = willsByRecipientList;
                        emit WillCreated(msg.sender,id);
                        return true;
                    }
                }
        }
        return false;
    }

    /**
     * @dev Get wills assigned to this owner address
     * @return wills
     */
    function getWillsByOwner(address ownerAddress) public view returns (Will[] memory){
        return willsByOwner[ownerAddress];
    }

    /**
     * @dev Get wills assigned to this recipient address
     * @return wills
     */
    function getWillsByRecipient(address recipientAddress) public view returns (Will[] memory){
        return willsByRecipient[recipientAddress];
    }

    function redeemWill(uint id) public{
        Will[] storage willsByRecipientList = willsByRecipient[msg.sender];
        require(
           willsByRecipientList.length > 0, "Will list not found"
        );
        Will memory will;
        for (uint8 index = 0; index < willsByRecipientList.length; index++) {
            if(willsByRecipientList[index].id == id) {
                will = willsByRecipientList[index];   
                break;
            }
        }
        require(
            will.recipient == msg.sender, "Wrong recipient"
        );
        require(
            will.redemptionDate < block.timestamp, "Transfer time not reached"
        );
        require(
            will.lastActivity < block.timestamp + 180 days, "Inheritance needs to wait 6 months from last owner activity"
        );
        (bool sent,) = will.recipient.call{value: will.ammount}("");
        require(sent, "Failed to send Ether");
        emit WillRedeemed(msg.sender,currentId);
    }

    function registerActivy(uint id) public {
        Will[] storage willsByOwnerList = willsByOwner[msg.sender];
        require(
           willsByOwnerList.length > 0, "Will list not found"
        );
        for (uint8 index = 0; index < willsByOwnerList.length; index++) {
            if(willsByOwnerList[index].id == id) {
               willsByOwnerList[index].lastActivity = block.timestamp;
               emit WillActivityRegistered(currentId,block.timestamp);
               break;
            }
        }
    }

}