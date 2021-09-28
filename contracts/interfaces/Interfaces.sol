// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IOracle {
    
    function latestRoundData()
     external
     view
     returns (
        uint80  roundId,
        int256  answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80  answeredInRound
    );

}