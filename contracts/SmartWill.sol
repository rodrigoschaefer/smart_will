// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

/**
 * @title SmartWill
 * @dev Time based resource transfers
 */
contract SmartWill {

    uint constant maxWillCount = 10;

    struct Will {
        uint id;
        address owner;
        uint ammount;
        uint unlockTime;
        uint lastActivity;
        address recipient;
    }

    uint currentId;

    mapping(address => Will[]) public willsByOwner;

    constructor() {
        currentId = 1;
    }

}