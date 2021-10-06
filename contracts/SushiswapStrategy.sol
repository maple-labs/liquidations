// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IERC20 }      from "../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";

import { ILender }            from "./interfaces/ILender.sol";
import { IUniswapRouterLike } from "./interfaces/Interfaces.sol";

contract SushiswapStrategy {

    address public constant SUSHISWAP_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    /// @dev Initiate a flash loan
    function flashBorrowLiquidation(
        address lender_, 
        uint256 swapAmount_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_,
        address profitDestination_
    ) 
        public 
    {
        uint256 repaymentAmount = ILender(lender_).getExpectedAmount(swapAmount_);

        ERC20Helper.approve(fundsAsset_, lender_, repaymentAmount);

        ILender(lender_).liquidatePortion(
            swapAmount_,  
            abi.encodeWithSelector(
                this.swap.selector, 
                swapAmount_, 
                repaymentAmount, 
                collateralAsset_, 
                middleAsset_, 
                fundsAsset_,
                profitDestination_
            )
        );
    }

    /// @dev Assumption - Before calling this function liquidator would transfer all the collateral to Liquidator (i.e proxy) contract.
    // TODO: Think about collateralAsset == fundsAsset
    function swap(
        uint256 swapAmount_,
        uint256 minReturnAmount_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_,
        address profitDestination_
    )
        external
    {
        // Get the liquidation amount from loan.
        require(IERC20(collateralAsset_).balanceOf(address(this)) == swapAmount_, "SushiswapStrategy:WRONG_COLLATERAL_AMT");
        
        ERC20Helper.approve(collateralAsset_, SUSHISWAP_ROUTER, swapAmount_);

        bool hasMiddleAsset = middleAsset_ != fundsAsset_ && middleAsset_ != address(0);

        address[] memory path = new address[](hasMiddleAsset ? 3 : 2);

        path[0] = address(collateralAsset_);
        path[1] = hasMiddleAsset ? middleAsset_ : fundsAsset_;

        if (hasMiddleAsset) path[2] = fundsAsset_;

        // Swap collateralAsset for Liquidity Asset.
        IUniswapRouterLike(SUSHISWAP_ROUTER).swapExactTokensForTokens(
            swapAmount_,
            minReturnAmount_,
            path,
            address(this),
            block.timestamp
        );

        require(ERC20Helper.transfer(fundsAsset_, profitDestination_, IERC20(fundsAsset_).balanceOf(address(this)) - minReturnAmount_), "SushiswapStrategy:PROFIT_TRANSFER");
    }

}

