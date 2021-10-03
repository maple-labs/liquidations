// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IStrategy {

    function triggerDefaultWithAmmId(
        bytes32 ammId_,
        address loan_,
        uint256 amount_,
        address collateralAsset_,
        address liquidityAsset_
    )
        external
        returns (
            uint256 amountLiquidated_,
            uint256 amountRecovered_
        );

}