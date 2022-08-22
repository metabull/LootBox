//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";

// File Contracts/CancellationRegistry.sol

contract CancellationRegistry is Ownable {
    mapping(address => bool) private registrants;

    mapping(address => uint256) private lastTransactionBlockNumber;
    mapping(bytes => bool) private orderDeactivations;

    modifier onlyRegistrants() {
        require(registrants[msg.sender], "The caller is not a registrant.");
        _;
    }

    function addRegistrant(address registrant) external onlyOwner {
        registrants[registrant] = true;
    }

    function removeRegistrant(address registrant) external onlyOwner {
        registrants[registrant] = false;
    }

    function cancelAllPreviousSignatures(address redeemer)
        external
        onlyRegistrants
    {
        lastTransactionBlockNumber[redeemer] = block.number;
    }

    function getLastTransactionBlockNumber(address redeemer)
        public
        view
        returns (uint256)
    {
        return lastTransactionBlockNumber[redeemer];
    }
}
