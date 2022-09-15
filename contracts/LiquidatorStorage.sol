// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ILiquidatorStorage } from "./interfaces/ILiquidatorStorage.sol";

abstract contract LiquidatorStorage is ILiquidatorStorage {

    // TODO: SC-8542: Add a state variable for collateral amount remaining so that a balance check is no longer needed.

    address public override collateralAsset;
    address public override fundsAsset;
    address public override loanManager;

    uint256 internal locked;

}
