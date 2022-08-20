// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { ILiquidator }                        from "./interfaces/ILiquidator.sol";
import { IAuctioneerLike, IMapleGlobalsLike } from "./interfaces/Interfaces.sol";

contract Liquidator is ILiquidator {

    uint256 private constant NOT_LOCKED = uint256(0);
    uint256 private constant LOCKED     = uint256(1);

    uint256 internal _locked;

    address public override immutable collateralAsset;
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

    /**
     * @param owner_           The address of an account that will have administrative privileges on this contract.
     * @param collateralAsset_ The address of the collateral asset being liquidated.
     * @param fundsAsset_      The address of the funds asset.
     * @param auctioneer_      The address of an Auctioneer.
     * @param destination_     The address to send funds asset after liquidation.
     * @param globals_         The address of a Maple Globals contract.
     */
    constructor(address owner_, address collateralAsset_, address fundsAsset_, address auctioneer_, address destination_, address globals_) {
        require((owner = owner_)     != address(0), "LIQ:C:INVALID_OWNER");
        require(destination_         != address(0), "LIQ:C:INVALID_DEST");
        require((globals = globals_) != address(0), "LIQ:C:INVALID_GLOBALS");

        require(ERC20Helper.approve(collateralAsset_, destination_, type(uint256).max), "LIQ:C:INVALID_C_APPROVE");
        require(ERC20Helper.approve(fundsAsset_,      destination_, type(uint256).max), "LIQ:C:INVALID_F_APPROVE");

        // NOTE: Auctioneer of zero is valid, since it is starting the contract off in a paused state.
        auctioneer      = auctioneer_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
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
        return IAuctioneerLike(auctioneer).getExpectedAmount(collateralAsset, swapAmount_);
    }

    function liquidatePortion(uint256 collateralAmount_, uint256 maxReturnAmount_, bytes calldata data_) external override whenProtocolNotPaused lock {
        // Transfer a requested amount of collateralAsset to the borrower.
        require(ERC20Helper.transfer(collateralAsset, msg.sender, collateralAmount_), "LIQ:LP:TRANSFER");

        // Perform a low-level call to msg.sender, allowing a swap strategy to be executed with the transferred collateral.
        msg.sender.call(data_);

        // Calculate the amount of fundsAsset required based on the amount of collateralAsset borrowed.
        uint256 returnAmount = getExpectedAmount(collateralAmount_);
        require(returnAmount <= maxReturnAmount_, "LIQ:LP:MAX_RETURN_EXCEEDED");

        emit PortionLiquidated(collateralAmount_, returnAmount);

        // Pull required amount of fundsAsset from the borrower, if this amount of funds cannot be recovered atomically, revert.
        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, address(this), returnAmount), "LIQ:LP:TRANSFER_FROM");
    }

}
