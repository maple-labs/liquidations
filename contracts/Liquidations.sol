// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ILoan }       from "../modules/loan/contracts/interfaces/ILoan.sol";
import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IERC20 }      from "../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";

import { ILiquidations }                         from "./interfaces/ILiquidations.sol";
import { IUniswapRouterLike, IMapleGlobalsLike } from "./interfaces/Interfaces.sol";

contract Liquidations is ILiquidations {

    using ERC20Helper for address;

    address public override globals;

    // ammPath [ammId][fromAsset][toAsset][facilitatorAsset].
    mapping(bytes32 => mapping(address => mapping (address => address))) ammPath;

    // Contract address that facilitate the interaction with AMM.
    mapping(bytes32 => address) public marketRouters;

    function initialize(address globals_) public {
        globals = globals_;
    }

    function addMarketPair(bytes32 ammId_, address fromAsset_, address toAsset_, address facilitatorAsset_) external override {
        require(fromAsset_ != address(0) && toAsset_ != address(0), "L:ZERO_ADDRESS");
        require(marketRouters[ammId_] != address(0), "L:MARKET_PLACE_NOT_EXISTS");
        ammPath[ammId_][fromAsset_][toAsset_] = facilitatorAsset_;
        emit MarketPairAdded(ammId_, fromAsset_, toAsset_, facilitatorAsset_); 
    } 

    function addMarketPlace(bytes32 ammId_, address router_) external override {
        require(router_ != address(0), "L:ZERO_ADDRESS");
        require(marketRouters[ammId_] == address(0), "L:MARKET_PLACE_ALREADY_EXISTS");
        marketRouters[ammId_] = router_;
        emit NewMarketAdded(ammId_, router_);
    }

    function _calcMinAmount(IMapleGlobalsLike globals_, address fromAsset_, address toAsset_, uint256 swapAmt_) internal view returns (uint256) {
        return
            swapAmt_
                 * globals_.getLatestPrice(fromAsset_)   // Convert from `fromAsset` value.
                 * 10 ** IERC20(toAsset_).decimals()     // Convert to `toAsset` decimal precision.
                 / globals_.getLatestPrice(toAsset_)     // Convert to `toAsset` value.
                 / 10 ** IERC20(fromAsset_).decimals();  // Convert from `fromAsset` decimal precision.
    }

    function triggerDefault(
        address collateralAsset_,
        address liquidityAsset_,
        address loan_
    ) 
        external
        override
        returns (
            uint256 amountLiquidated,
            uint256 amountRecovered
        ) 
    {
        return triggerDefaultWithAmmId(collateralAsset_, liquidityAsset_, loan_, bytes32("Uniswap-v2"));
    }

    function triggerDefaultWithAmmId(
        address collateralAsset_,
        address liquidityAsset_,
        address loan_,
        bytes32 ammId_
    )
        public
        override
        returns (
            uint256 amountLiquidated_,
            uint256 amountRecovered_
        )
    {
        // Get the liquidation amount from loan.
        uint256 liquidationAmt = ILoan(loan_).collateral();

        // Transfer collateral amount from loan.
        IERC20(collateralAsset_).transferFrom(loan_, address(this), liquidationAmt);
        
        if (collateralAsset_ == liquidityAsset_ || liquidationAmt == uint256(0)) return (liquidationAmt, liquidationAmt);

        address router = marketRouters[ammId_];

        collateralAsset_.approve(router, uint256(0));
        collateralAsset_.approve(router, liquidationAmt);

        // Get minimum amount of loan asset get after swapping collateral asset.
        uint256 minAmount = _calcMinAmount(IMapleGlobalsLike(globals), collateralAsset_, liquidityAsset_, liquidationAmt);

        // Generate Uniswap path.
        address uniswapAssetForPath = ammPath[ammId_][collateralAsset_][liquidityAsset_];
        bool middleAsset = uniswapAssetForPath != liquidityAsset_ && uniswapAssetForPath != address(0);

        address[] memory path = new address[](middleAsset ? 3 : 2);

        path[0] = address(collateralAsset_);
        path[1] = middleAsset ? uniswapAssetForPath : liquidityAsset_;

        if (middleAsset) path[2] = liquidityAsset_;

        // Swap collateralAsset for Liquidity Asset.
        uint256[] memory returnAmounts = IUniswapRouterLike(marketRouters[ammId_]).swapExactTokensForTokens(
            liquidationAmt,
            minAmount - (minAmount * IMapleGlobalsLike(globals).maxSwapSlippage()) / 10_000,
            path,
            address(this),
            block.timestamp
        );

        return(returnAmounts[0], returnAmounts[path.length - 1]);
    }
}

