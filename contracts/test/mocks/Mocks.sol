// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IERC20Like, IMapleGlobalsLike, IOracleLike } from "../../interfaces/Interfaces.sol";

contract AuctioneerMock {

    address public owner;
    address public collateralAsset;
    address public fundsAsset;
    address public globals;
    uint256 public allowedSlippage;
    uint256 public minRatio;

    constructor(address globals_, address collateralAsset_, address fundsAsset_, uint256 allowedSlippage_, uint256 minRatio_) {
        owner           = msg.sender;
        globals         = globals_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
        allowedSlippage = allowedSlippage_;
        minRatio        = minRatio_;
    }

    function getExpectedAmount(uint256 swapAmount_) public view returns (uint256 returnAmount_) {
        uint256 oracleAmount = 
            swapAmount_
                * IMapleGlobalsLike(globals).getLatestPrice(collateralAsset)  // Convert from `fromAsset` value.
                * 10 ** IERC20Like(fundsAsset).decimals()                     // Convert to `toAsset` decimal precision.
                * (10_000 - allowedSlippage)                                  // Multiply by allowed slippage basis points
                / IMapleGlobalsLike(globals).getLatestPrice(fundsAsset)       // Convert to `toAsset` value.
                / 10 ** IERC20Like(collateralAsset).decimals()                // Convert from `fromAsset` decimal precision.
                / 10_000;                                                     // Divide basis points for slippage
        
        uint256 minRatioAmount = swapAmount_ * minRatio / 10 ** IERC20Like(collateralAsset).decimals();

        return oracleAmount > minRatioAmount ? oracleAmount : minRatioAmount;
    }
}

contract MapleGlobalsMock {

    mapping (address => address) public oracleFor;

    function getLatestPrice(address asset) external view returns (uint256) {
        (, int256 price,,,) = IOracleLike(oracleFor[asset]).latestRoundData();
        return uint256(price);
    }

    function setPriceOracle(address asset, address oracle) external {
        oracleFor[asset] = oracle;
    }

}
