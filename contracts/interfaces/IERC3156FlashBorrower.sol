// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IERC3156FlashBorrower {

    // /**
    //  * @dev Receive a flash loan.
    //  * @param initiator The initiator of the loan.
    //  * @param token The loan currency.
    //  * @param amount The amount of tokens lent.
    //  * @param fee The additional amount of tokens to repay.
    //  * @param data Arbitrary data structure, intended to contain user-defined parameters.
    //  * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
    //  */
    function onFlashLoan(address initiator_, bytes calldata data_) external returns (bytes32);
}
