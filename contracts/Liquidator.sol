// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { ILiquidator }                        from "./interfaces/ILiquidator.sol";
import { IAuctioneerLike, IMapleGlobalsLike } from "./interfaces/Interfaces.sol";

contract Liquidator is ILiquidator {

    uint256 private constant NOT_LOCKED = 0;
    uint256 private constant LOCKED     = 1;
    
    uint256 internal _locked;
    
    address public override immutable collateralAsset;
    address public override immutable destination;
    address public override immutable fundsAsset;
    address public override immutable globals;
    address public override immutable owner;

    address public override auctioneer;

    /*****************/
    /*** Modifiers ***/
    /*****************/

    modifier whenProtocolNotPaused() {
        require(!IMapleGlobalsLike(globals).protocolPaused(), "LIQ:PROTOCOL_PAUSED");
        _;
    }

    modifier lock() {
        require(_locked == NOT_LOCKED, "LIQ:LOCKED");
        _locked = LOCKED;
        _;
        _locked = NOT_LOCKED;
    }

    constructor(address owner_, address collateralAsset_, address fundsAsset_, address auctioneer_, address destination_, address globals_) {
        require((owner           = owner_)           != address(0), "LIQ:C:INVALID_OWNER");
        require((collateralAsset = collateralAsset_) != address(0), "LIQ:C:INVALID_COL_ASSET");
        require((fundsAsset      = fundsAsset_)      != address(0), "LIQ:C:INVALID_FUNDS_ASSET");
        require((destination     = destination_)     != address(0), "LIQ:C:INVALID_DEST");

        require(!IMapleGlobalsLike(globals = globals_).protocolPaused(), "LIQ:C:INVALID_GLOBALS");

        // NOTE: Auctioneer of zero is valid, since it is starting the contract off in a paused state.
        auctioneer = auctioneer_;
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

    function liquidatePortion(uint256 swapAmount_, uint256 maxReturnAmount_, bytes calldata data_) external whenProtocolNotPaused lock override {
        require(ERC20Helper.transfer(collateralAsset, msg.sender, swapAmount_), "LIQ:LP:TRANSFER");

        msg.sender.call(data_);

        uint256 returnAmount = getExpectedAmount(swapAmount_);
        require(returnAmount <= maxReturnAmount_, "LIQ:LP:MAX_RETURN_EXCEEDED");

        emit PortionLiquidated(swapAmount_, returnAmount);

        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, destination, returnAmount), "LIQ:LP:TRANSFER_FROM");
    }

}
