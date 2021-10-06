// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IERC3156FlashLender } from "./IERC3156FlashLender.sol";

interface ILender is IERC3156FlashLender {

    function getExpectedAmount(uint256 swapAmount) external view returns (uint256 returnAmount);

    function liquidatePortion(uint256 swapAmount_, bytes calldata encodedArguments) external;

}
