// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper, IERC20 } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { ILender }               from "./interfaces/ILender.sol";
import { IERC3156FlashBorrower } from "./interfaces/IERC3156FlashBorrower.sol";

interface IMapleGlobalsLike {

    function maxSwapSlippage() external view returns(uint256);

    function getLatestPrice(address asset) external view returns(uint256);

}

contract Liquidator {

    address public owner;
    address public collateralAsset;
    address public destination;
    address public fundsAsset;
    address public globals;
    uint256 public allowedSlippage;
    uint256 public minRatio;

    constructor(address globals_, address collateralAsset_, address fundsAsset_, uint256 allowedSlippage_, uint256 minRatio_, address destination_) {
        owner           = msg.sender;
        globals         = globals_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
        allowedSlippage = allowedSlippage_;
        destination     = destination_;
        minRatio        = minRatio_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "L:INVALID_ADMIN");
        _;
    }

    function setNewMinRation(uint256 minRatio_) external onlyOwner {
        minRatio = minRatio_;
    }

    function setAllowedSlippage_(uint256 allowedSlippage_) external onlyOwner {
        allowedSlippage = allowedSlippage_;
    }

    // TODO: Allow for setAllowedSlippage function

    function getReturnAmount(uint256 swapAmount_) public view returns (uint256 returnAmount_) {
        return
            swapAmount_
                * IMapleGlobalsLike(globals).getLatestPrice(collateralAsset)  // Convert from `fromAsset` value.
                * 10 ** IERC20(fundsAsset).decimals()                         // Convert to `toAsset` decimal precision.
                * (10_000 - allowedSlippage)                                  // Multiply by allowed slippage basis points
                / IMapleGlobalsLike(globals).getLatestPrice(fundsAsset)       // Convert to `toAsset` value.
                / 10 ** IERC20(collateralAsset).decimals()                    // Convert from `fromAsset` decimal precision.
                / 10_000;                                                     // Divide basis points for slippage
    }

    function liquidatePortion(address liquidator_, uint256 swapAmount_, bytes calldata data_) external {
        ERC20Helper.transfer(collateralAsset, liquidator_, swapAmount_);

        liquidator_.call(data_);

        uint256 amount1 = getReturnAmount(swapAmount_);
        uint256 amount2 = (swapAmount_ * minRatio) / 10_000;

        require(ERC20Helper.transferFrom(fundsAsset, liquidator_, address(this), amount1 > amount2 ? amount1 : amount2));

        if (IERC20(collateralAsset).balanceOf(address(this)) != uint256(0)) return;

        require(ERC20Helper.transfer(fundsAsset, destination, IERC20(fundsAsset).balanceOf(address(this))));
    }

}
