//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.1;

interface ICancellationRegistry {
    function addRegistrant(address registrant) external;

    function removeRegistrant(address registrant) external;

    function cancelAllPreviousSignatures(address redeemer) external;

    function getLastTransactionBlockNumber(address redeemer)
        external
        view
        returns (uint256);
}
