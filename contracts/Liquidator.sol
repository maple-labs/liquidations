// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";
import { IMapleProxyFactory }    from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { ILiquidator } from "./interfaces/ILiquidator.sol";

import { ILoanManagerLike, IMapleGlobalsLike } from "./interfaces/Interfaces.sol";

import { LiquidatorStorage } from "./LiquidatorStorage.sol";

/*

    ██╗     ██╗ ██████╗ ██╗   ██╗██╗██████╗  █████╗ ████████╗ ██████╗ ██████╗
    ██║     ██║██╔═══██╗██║   ██║██║██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗
    ██║     ██║██║   ██║██║   ██║██║██║  ██║███████║   ██║   ██║   ██║██████╔╝
    ██║     ██║██║▄▄ ██║██║   ██║██║██║  ██║██╔══██║   ██║   ██║   ██║██╔══██╗
    ███████╗██║╚██████╔╝╚██████╔╝██║██████╔╝██║  ██║   ██║   ╚██████╔╝██║  ██║
    ╚══════╝╚═╝ ╚══▀▀═╝  ╚═════╝ ╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝

*/

contract Liquidator is ILiquidator, LiquidatorStorage, MapleProxiedInternals {

    uint256 private constant LOCKED     = uint256(1);
    uint256 private constant NOT_LOCKED = uint256(0);

    /******************************************************************************************************************************/
    /*** Modifiers                                                                                                              ***/
    /******************************************************************************************************************************/

    modifier whenProtocolNotPaused() {
        require(!IMapleGlobalsLike(globals()).protocolPaused(), "LIQ:PROTOCOL_PAUSED");

        _;
    }

    modifier lock() {
        require(locked == NOT_LOCKED, "LIQ:LOCKED");

        locked = LOCKED;

        _;

        locked = NOT_LOCKED;
    }

    /******************************************************************************************************************************/
    /*** Migration Functions                                                                                                    ***/
    /******************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(),        "LIQ:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "LIQ:M:FAILED");
    }

    function setImplementation(address implementation_) external override {
        require(msg.sender == _factory(), "LIQ:SI:NOT_FACTORY");

        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenProtocolNotPaused {
        address poolDelegate_ = poolDelegate();

        require(msg.sender == poolDelegate_ || msg.sender == governor(), "LIQ:U:NOT_AUTHORIZED");

        IMapleGlobalsLike mapleGlobals = IMapleGlobalsLike(globals());

        if (msg.sender == poolDelegate_) {
            require(mapleGlobals.isValidScheduledCall(msg.sender, address(this), "LIQ:UPGRADE", msg.data), "LIQ:U:INVALID_SCHED_CALL");

            mapleGlobals.unscheduleCall(msg.sender, "LIQ:UPGRADE", msg.data);
        }

        IMapleProxyFactory(_factory()).upgradeInstance(version_, arguments_);
    }

    /******************************************************************************************************************************/
    /*** Liquidation Functions                                                                                                  ***/
    /******************************************************************************************************************************/

    function liquidatePortion(uint256 collateralAmount_, uint256 maxReturnAmount_, bytes calldata data_) external override whenProtocolNotPaused lock {
        require(msg.sender != collateralAsset && msg.sender != fundsAsset, "LIQ:LP:INVALID_CALLER");

        // Transfer a requested amount of collateralAsset to the borrower.
        require(ERC20Helper.transfer(collateralAsset, msg.sender, collateralAmount_), "LIQ:LP:TRANSFER");

        collateralRemaining -= collateralAmount_;

        // Perform a low-level call to msg.sender, allowing a swap strategy to be executed with the transferred collateral.
        msg.sender.call(data_);

        // Calculate the amount of fundsAsset required based on the amount of collateralAsset borrowed.
        uint256 returnAmount = getExpectedAmount(collateralAmount_);
        require(returnAmount <= maxReturnAmount_, "LIQ:LP:MAX_RETURN_EXCEEDED");

        emit PortionLiquidated(collateralAmount_, returnAmount);

        // Pull required amount of fundsAsset from the borrower, if this amount of funds cannot be recovered atomically, revert.
        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, address(this), returnAmount), "LIQ:LP:TRANSFER_FROM");
    }

    function pullFunds(address token_, address destination_, uint256 amount_) external override {
        require(msg.sender == loanManager, "LIQ:PF:NOT_LM");

        emit FundsPulled(token_, destination_, amount_);

        require(ERC20Helper.transfer(token_, destination_, amount_), "LIQ:PF:TRANSFER");
    }

    function setCollateralRemaining(uint256 collateralAmount_) external override {
        require(msg.sender == loanManager, "LIQ:SCR:NOT_LM");

        collateralRemaining = collateralAmount_;
    }

    function getExpectedAmount(uint256 swapAmount_) public view override returns (uint256 expectedAmount_) {
        return ILoanManagerLike(loanManager).getExpectedAmount(collateralAsset, swapAmount_);
    }

    /******************************************************************************************************************************/
    /*** View Functions                                                                                                         ***/
    /******************************************************************************************************************************/

    function factory() public view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view returns (address globals_) {
        globals_ = ILoanManagerLike(loanManager).globals();
    }

    function governor() public view returns (address governor_) {
        governor_ = ILoanManagerLike(loanManager).governor();
    }

    function implementation() public view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function poolDelegate() public view returns (address poolDelegate_) {
        poolDelegate_ = ILoanManagerLike(loanManager).poolDelegate();
    }

}
