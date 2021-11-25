// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

/**
 * @title SmartWill
 * @dev Time based resource transfers
 */
contract SmartWill {

    event WillCreated(address owner, uint id);
    event WillRefunded(address owner, uint id);
    event WillActivityRegistered(uint id, uint blockTime);
    event WillRedeemed(address recipient, uint id, uint blockTime, uint redemptionTime);
    event BalanceChanged(address owner, uint balance);
    event RedemptionError(uint blockTime, uint redemptionTime);

    uint constant maxWillCount = 10;

    struct Will {
        uint id;
        address owner;
        uint ammount;
        uint redemptionDate;
        uint lastActivity;
        address payable recipient;
        bool redeemed;
    }

    uint currentId;

    mapping(address => Will[])  willsByOwner;
    mapping(address => Will[])  willsByRecipient;

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
            lastActivity: 0,
            redeemed: false
        });
        wills.push(will);
        
        Will[] storage willsByRecipientList = willsByRecipient[recipient];
        require(willsByRecipientList.length < maxWillCount, "Maximum number of wills reached for this retriever");    
        willsByRecipientList.push(will);
        
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
        Will[] storage willsByOwnerList = willsByOwner[msg.sender];
        for (uint8 index = 0; index < willsByOwnerList.length; index++) {
            if(willsByOwnerList[index].id == id) {
               return willsByOwnerList[index];
            }
        }
        revert('Not found');
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

    function redeemWill(uint id) external{
        Will[] storage willsByRecipientList = willsByRecipient[msg.sender];
        require(
           willsByRecipientList.length > 0, "Will list not found"
        );
        bool recipientFound = false;
        for (uint8 index = 0; index < willsByRecipientList.length; index++) {
            if(willsByRecipientList[index].id == id) {
                require(
                    willsByRecipientList[index].recipient == msg.sender, "Wrong recipient"
                );
                require(
                    willsByRecipientList[index].redemptionDate < block.timestamp, "Transfer time not reached"
                );
                require(
                    willsByRecipientList[index].lastActivity < block.timestamp - 180 days, "Inheritance needs to wait 6 months from last owner activity"
                );
                (bool sent,) = willsByRecipientList[index].recipient.call{value: willsByRecipientList[index].ammount}("");
                require(sent, "Failed to send Ether");
                willsByRecipientList[index].redeemed = true;
                emit WillRedeemed(msg.sender,id, block.timestamp,willsByRecipientList[index].redemptionDate);
                recipientFound = true;
                break;
            }
        }
        require(recipientFound, 'Recipient not found');
        bool ownerFound = false;
        Will[] storage willsByOwnerList = willsByOwner[msg.sender];
        require(
           willsByOwnerList.length > 0, "Will list not found"
        );
        for (uint8 index = 0; index < willsByOwnerList.length; index++) {
            if(willsByOwnerList[index].id == id) {
                willsByOwnerList[index].redeemed = true;
                ownerFound = true;
            }
        }
        require(ownerFound, 'Owner not found');
    }

    /**
     * @dev Deletes a will and returns value to owner (minus gas costs)
     */
    function refundWill(uint id) public returns (bool){
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

                        (bool sent,) = will.owner.call{value: will.ammount}("");
                        require(sent, "Failed to send Ether");
                        
                        willsByRecipientList[index] = willsByRecipientList[willsByRecipientList.length-1];
                        willsByRecipientList.pop();
                        willsByRecipient[will.recipient] = willsByRecipientList;
                        emit WillRefunded(msg.sender,id);
                        return true;
                    }
                }
        }
        return false;
    }

    function registerActivy(uint id) public {
        uint blockTime = block.timestamp;
        Will[] storage willsByOwnerList = willsByOwner[msg.sender];
        require(
           willsByOwnerList.length > 0, "Owner Will list not found"
        );
        bool ownerFound = false;
        for (uint8 index = 0; index < willsByOwnerList.length; index++) {
            if(willsByOwnerList[index].id == id) {
               willsByOwnerList[index].lastActivity = blockTime;
               ownerFound = true;
               break;
            }
        }
        require(ownerFound, 'Owner not found');
        Will[] storage willsByRecipientList = willsByRecipient[msg.sender];
        require(
           willsByRecipientList.length > 0, "Recipient Will list not found"
        );
        bool recipientFound = false;
        for (uint8 index = 0; index < willsByRecipientList.length; index++) {
            if(willsByRecipientList[index].id == id) {
               willsByRecipientList[index].lastActivity = blockTime;
               recipientFound = true;
               break;
            }
        }
        require(recipientFound, 'Recipient not found');
        emit WillActivityRegistered(id,blockTime);
    }

}