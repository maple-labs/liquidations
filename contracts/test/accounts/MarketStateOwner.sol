// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMarketState } from "../../interfaces/IMarketState.sol";

contract MarketStateOwner {

    function marketState_try_addMarketPair(
        address target_,
        bytes32 ammId_,
        address fromAsset_,
        address toAsset_,
        address facilitatorAsset_
    ) external returns(bool ok) {
        (ok,) = target_.call(abi.encodeWithSelector(IMarketState.addMarketPair.selector, ammId_, fromAsset_, toAsset_, facilitatorAsset_));
    }
}