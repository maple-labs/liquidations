// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper, IERC20 } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { ILender }               from "./interfaces/ILender.sol";
import { IERC3156FlashBorrower } from "./interfaces/IERC3156FlashBorrower.sol";
import { IMarketState }          from "./interfaces/IMarketState.sol";
import { IStrategy }             from "./interfaces/IStrategy.sol";

interface IMapleGlobalsLike {

    function maxSwapSlippage() external view returns(uint256);

    function getLatestPrice(address asset) external view returns(uint256);

}

contract Liquidations {

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.MapleFinance.onFlashLoan");

    address public owner;
    address public collateralAsset;
    address public fundsAsset;
    address public globals;
    uint256 public allowedSlippage;

    constructor(address globals_, address collateralAsset_, address fundsAsset_, uint256 allowedSlippage_) {
        owner           = msg.sender;
        globals         = globals_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
        allowedSlippage = allowedSlippage_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "L:INVALID_ADMIN");
        _;
    }

    function getReturnAmount(uint256 swapAmount_) public view returns (uint256 returnAmount_) {
        return
            swapAmount_
                * IMapleGlobalsLike(globals).getLatestPrice(collateralAsset)  // Convert from `fromAsset` value.
                * 10 ** IERC20(fundsAsset).decimals()                         // Convert to `toAsset` decimal precision.
                * allowedSlippage                                             // Multiply by allowed slippage basis points
                / IMapleGlobalsLike(globals).getLatestPrice(fundsAsset)       // Convert to `toAsset` value.
                / 10 ** IERC20(collateralAsset).decimals()                    // Convert from `fromAsset` decimal precision.
                / 10_000;                                                     // Divide basis points for slippage
    }

    function flashLoanLiquidation(
        address liquidationStrategy_, 
        uint256 swapAmount_, 
        bytes calldata data_,
        bytes calldata encodedArguments_
    ) 
        external returns (bool) 
    {
        uint256 returnAmount = getReturnAmount(swapAmount_);

        // Transfer collateral to liquidation strategy
        require(
            IERC20(collateralAsset).transfer(liquidationStrategy_, swapAmount_),
            "FLASH_LEND:TRANSFER"
        );

        // Perform flashloan callback
        require(
            IERC3156FlashBorrower(liquidationStrategy_).onFlashLoan(msg.sender, data_) == CALLBACK_SUCCESS, 
            "FLASH_LEND:CALLBACK"
        );

        // Perform custom swap function, passing in custom arguments
        ( bool success, ) = liquidationStrategy_.call(encodedArguments_);
        require(success, "FLASH_LEND:SWAP_CALL");

        // Recover expected funds from liquidation strategy
        require(
            IERC20(fundsAsset).transferFrom(liquidationStrategy_, address(this), returnAmount),
            "FLASH_LEND:REPAY"
        );
        
        return true;
    }
    
}
