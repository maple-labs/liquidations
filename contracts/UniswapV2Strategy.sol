// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ILoan }       from "../modules/loan/contracts/interfaces/ILoan.sol";
import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IERC20 }      from "../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";

import { IStrategy }                             from "./interfaces/IStrategy.sol";
import { IUniswapRouterLike, IMapleGlobalsLike } from "./interfaces/Interfaces.sol";
import { IMarketState }                          from "./interfaces/IMarketState.sol";

import { LiquidationsStateReader } from "./LiquidationsStateReader.sol";

contract UniswapV2Strategy is LiquidationsStateReader, IStrategy {

    using ERC20Helper for address;

    /// @dev Assumption - Before calling this function liquidator would transfer all the collateral to Liquidations (i.e proxy) contract.
    function triggerDefaultWithAmmId(
        bytes32 ammId_,
        address loan_,
        uint256 amount_,
        address collateralAsset_,
        address liquidityAsset_
    )
        external override
        returns (
            uint256 amountLiquidated_,
            uint256 amountRecovered_
        )
    {
        // Get the liquidation amount from loan.
        require(IERC20(collateralAsset_).balanceOf(address(this)) >= amount_, "UniswapV2Strategy:INSUFFICIENT_COLLATERAL");

        IMarketState marketState = IMarketState(getMarketStateAddress());
        
        if (collateralAsset_ == liquidityAsset_ || amount_ == uint256(0)) return (amount_, amount_);

        address router = marketState.getRouter(ammId_);

        collateralAsset_.approve(router, uint256(0));
        collateralAsset_.approve(router, amount_);

        // Get minimum amount of loan asset get after swapping collateral asset.
        uint256 minAmount = marketState.calcMinAmount(IMapleGlobalsLike(marketState.globals()), collateralAsset_, liquidityAsset_, amount_);

        // Generate Uniswap path.
        address uniswapAssetForPath = marketState.getAmmPath(ammId_, collateralAsset_, liquidityAsset_);
        bool middleAsset = uniswapAssetForPath != liquidityAsset_ && uniswapAssetForPath != address(0);

        address[] memory path = new address[](middleAsset ? 3 : 2);

        path[0] = address(collateralAsset_);
        path[1] = middleAsset ? uniswapAssetForPath : liquidityAsset_;

        if (middleAsset) path[2] = liquidityAsset_;

        // Swap collateralAsset for Liquidity Asset.
        uint256[] memory returnAmounts = IUniswapRouterLike(marketState.getRouter(ammId_)).swapExactTokensForTokens(
            amount_,
            minAmount - (minAmount * IMapleGlobalsLike(marketState.globals()).maxSwapSlippage()) / 10_000,
            path,
            address(this),
            block.timestamp
        );

        return(returnAmounts[0], returnAmounts[path.length - 1]);
    }

}

