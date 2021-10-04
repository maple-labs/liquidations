// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IERC3156FlashLender } from "./IERC3156FlashLender.sol";

interface ILender is IERC3156FlashLender {

    function getReturnAmount(uint256 swapAmount) external view returns (uint256 returnAmount);

    function flashLoanLiquidation(
        address liquidationStrategy_, 
        uint256 swapAmount_, 
        bytes calldata data,
        bytes calldata encodedArguments
    ) external returns (bool);

}
