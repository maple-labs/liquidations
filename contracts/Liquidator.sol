// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { ILiquidator }     from "./interfaces/ILiquidator.sol";
import { IAuctioneerLike } from "./interfaces/Interfaces.sol";

contract Liquidator is ILiquidator {

    address public override auctioneer;
    address public override collateralAsset;
    address public override destination;
    address public override fundsAsset;
    address public override owner;

    bool internal _locked;

    constructor(address owner_, address collateralAsset_, address fundsAsset_, address auctioneer_, address destination_) {
        require(
            owner_           != address(0) && 
            collateralAsset_ != address(0) && 
            fundsAsset_      != address(0) && 
            auctioneer_      != address(0) && 
            destination_     != address(0), 
            "LIQ:C:INVALID_PARAMETER"
        );
        
        owner           = owner_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
        auctioneer      = auctioneer_;
        destination     = destination_;
    }

    function setAuctioneer(address auctioneer_) external override {
        require(msg.sender == owner, "LIQ:SA:NOT_OWNER");

        emit AuctioneerSet(auctioneer = auctioneer_);
    }

    function pullFunds(address token_, address destination_, uint256 amount_) external override {
        require(msg.sender == owner, "LIQ:PF:NOT_OWNER");

        emit FundsPulled(token_, destination_, amount_);

        require(ERC20Helper.transfer(token_, destination_, amount_), "LIQ:PF:TRANSFER");
    }

    function getExpectedAmount(uint256 swapAmount_) public view override returns (uint256 expectedAmount_) {
        return IAuctioneerLike(auctioneer).getExpectedAmount(swapAmount_);
    }

    function liquidatePortion(uint256 swapAmount_, uint256 maxReturnAmount_, bytes calldata data_) external override {
        require(!_locked, "LIQ:LP:LOCKED");

        _locked = true;

        require(ERC20Helper.transfer(collateralAsset, msg.sender, swapAmount_), "LIQ:LP:TRANSFER");

        msg.sender.call(data_);

        uint256 returnAmount = getExpectedAmount(swapAmount_);
        require(returnAmount <= maxReturnAmount_, "LIQ:LP:MAX_RETURN_EXCEEDED");

        emit PortionLiquidated(swapAmount_, returnAmount);

        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, destination, returnAmount), "LIQ:LP:TRANSFER_FROM");

        _locked = false;
    }

}
