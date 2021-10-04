// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleGlobalsLike } from "./Interfaces.sol";

interface IMarketState {

    event MarketPairAdded (bytes32 ammId, address fromAsset, address toAsset, address facilitatorAsset);
    event NewMarketAdded  (bytes32 ammId, address router);
    event NewStrategyAdded(bytes32 ammId, address strategy);

    function addMarketPair(bytes32 ammId, address fromAsset_, address toAsset_, address facilitatorAsset_) external;

    function addMarketPlace(bytes32 ammId_, address router_) external;

    function addStrategy(bytes32 ammId_, address strategy_) external;

    function calcMinAmount(IMapleGlobalsLike globals_, address fromAsset_, address toAsset_, uint256 swapAmt_) external view returns (uint256);

    function setGlobals(address newGlobals_) external;

    function globals() external view returns(address);

    function getAmmPath(bytes32 ammId_, address fromAsset_, address toAsset_) external view returns(address facilitatorAsset_);

    function getRouter(bytes32 ammId_) external view returns(address router_);

    function getStrategy(bytes32 ammId_) external view returns(address strategy_);

}