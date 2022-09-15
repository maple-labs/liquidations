// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ILiquidatorStorage } from "./interfaces/ILiquidatorStorage.sol";

abstract contract LiquidatorStorage is ILiquidatorStorage {

    address public override collateralAsset;
    address public override fundsAsset;
    address public override loanManager;

    uint256 public override collateralRemaining;

    uint256 internal locked;

}
