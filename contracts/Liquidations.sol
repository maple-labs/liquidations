// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ILoan }  from "../modules/loan/contracts/interfaces/ILoan.sol";
import { IERC20 } from "../modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Util }   from "../modules/util/contracts/Util.sol";
import { IMapleGlobals } from "../modules/util/contracts/interfaces/IMapleGlobals.sol";

import { ILiquidations } from "./interfaces/ILiquidations.sol";

contract Liquidations is ILiquidations {

    address public override globals;

    mapping(bytes32 => MarketPlace) public override markets;

    function initialize(address globals_) public {
        globals = globals_;
    }

    function addMarketPair(bytes32 ammId, address fromAsset_, address toAsset_, address facilitatorAsset_) external {
        require(fromAsset_ != address(0) && toAsset_ != address(0), "L:ZERO_ADDRESS");
        require(markets[ammId].interactor != address(0), "L:MARKET_PLACE_NOT_EXISTS");
        markets[ammId].ammPath[fromAsset_][toAsset_] = facilitatorAsset_;
        emit MarketPairAdded(ammId, fromAsset_, toAsset_, facilitatorAsset_); 
    } 

    function addMarketPlace(bytes32 ammId_, address router_) external {
        require(router_ != address(0), "L:ZERO_ADDRESS");
        require(markets[ammId_].interactor == address(0), "L:MARKET_PLACE_ALREADY_EXISTS");
        markets[ammId_] = MarketPlace { ammId: ammId_, interactor: router_};
        emit NewMarketAdded(ammId_, router_);
    }

    function triggerDefault(
        address collateralAsset,
        address liquidityAsset,
        address loan
    ) 
        external
        returns (
            uint256 amountLiquidated,
            uint256 amountRecovered
        ) 
    {
        return triggerDefaultWithAmmId(collateralAsset, liquidityAsset, loan, bytes32("Uniswap-v2"));
    }

    function triggerDefaultWithAmmId(
        address collateralAsset,
        address liquidityAsset,
        address loan,
        bytes32 ammId
    )
        public
        returns (
            uint256 amountLiquidated,
            uint256 amountRecovered
        )
    {
        // Get the liquidation amount from loan.
        uint256 liquidationAmt = ILoan(loan).collateral();

        // Transfer collateral amount from loan.
        IERC20(collateralAsset).transferFrom(loan, address(this), liquidationAmt);
        
        if (address(collateralAsset) == liquidityAsset || liquidationAmt == uint256(0)) return (liquidationAmt, liquidationAmt);

        address router = markets[ammId].interactor;

        collateralAsset.safeApprove(router, uint256(0));
        collateralAsset.safeApprove(router, liquidationAmt);

        // Get minimum amount of loan asset get after swapping collateral asset.
        uint256 minAmount = Util.calcMinAmount(IMapleGlobals(address(globals)) , collateralAsset, liquidityAsset, liquidationAmt);

        // Generate Uniswap path.
        address uniswapAssetForPath = markets[ammId].ammPath[collateralAsset][liquidityAsset];
        bool middleAsset = uniswapAssetForPath != liquidityAsset && uniswapAssetForPath != address(0);

        address[] memory path = new address[](middleAsset ? 3 : 2);

        path[0] = address(collateralAsset);
        path[1] = middleAsset ? uniswapAssetForPath : liquidityAsset;

        if (middleAsset) path[2] = liquidityAsset;

        // Swap collateralAsset for Liquidity Asset.
        uint256[] memory returnAmounts = IUniswapRouterLike(UNISWAP_ROUTER).swapExactTokensForTokens(
            liquidationAmt,
            minAmount.sub(minAmount.mul(globals.maxSwapSlippage()).div(10_000)),
            path,
            address(this),
            block.timestamp
        );

        return(returnAmounts[0], returnAmounts[path.length - 1]);
    }
}

