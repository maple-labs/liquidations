// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMarketState } from "../../interfaces/IMarketState.sol";

contract MarketStateOwner {

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function marketState_try_addMarketPair(
        address target_,
        bytes32 ammId_,
        address fromAsset_,
        address toAsset_,
        address facilitatorAsset_
    ) external returns(bool ok) {
        (ok,) = target_.call(abi.encodeWithSelector(IMarketState.addMarketPair.selector, ammId_, fromAsset_, toAsset_, facilitatorAsset_));
    }

    function marketState_try_addMarketPlace(
        address target_,
        bytes32 ammId_,
        address router_
    ) external returns(bool ok) {
        (ok,) = target_.call(abi.encodeWithSelector(IMarketState.addMarketPlace.selector, ammId_, router_));
    }

    function marketState_try_addStrategy(
        address target_,
        bytes32 ammId_,
        address strategy_
    ) external returns(bool ok) {
        (ok,) = target_.call(abi.encodeWithSelector(IMarketState.addStrategy.selector, ammId_, strategy_));
    }

    function marketState_try_setGlobals(
        address target_,
        address newGlobals_
    ) external returns(bool ok) {
        (ok,) = target_.call(abi.encodeWithSelector(IMarketState.addMarketPair.selector, newGlobals_));
    }

    /************************/
    /*** Direct Functions ***/
    /************************/

    function marketState_addMarketPair(
        address target_,
        bytes32 ammId_,
        address fromAsset_,
        address toAsset_,
        address facilitatorAsset_
    ) external {
        IMarketState(target_).addMarketPair(ammId_, fromAsset_, toAsset_, facilitatorAsset_);
    }

    function marketState_addMarketPlace(
        address target_,
        bytes32 ammId_,
        address router_
    ) external {
        IMarketState(target_).addMarketPlace(ammId_, router_);
    }

    function marketState_addStrategy(
        address target_,
        bytes32 ammId_,
        address strategy_
    ) external {
        IMarketState(target_).addStrategy(ammId_, strategy_);
    }

    function marketState_setGlobals(
        address target_,
        address newGlobals_
    ) external {
        IMarketState(target_).setGlobals(newGlobals_);
    }
}