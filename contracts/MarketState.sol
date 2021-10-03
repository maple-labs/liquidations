// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IERC20 }  from "../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";
import { Ownable } from "../modules/oz-contracts/contracts/access/Ownable.sol";

import { IMarketState, IMapleGlobalsLike } from "./interfaces/IMarketState.sol";

contract MarketState is IMarketState, Ownable {

    address _globals;

    // ammPath [ammId][fromAsset][toAsset][facilitatorAsset].
    mapping(bytes32 => mapping(address => mapping (address => address))) _ammPath;

    // Contract address that facilitate the interaction with AMM.
    mapping(bytes32 => address) _marketRouters;

    // Contains the strategy use to liquidate the collateral.
    mapping(bytes32 => address) _strategy;

    constructor(address globals_, address owner_) {
        _globals = globals_;
        _transferOwnership(owner_);
    }

    function addMarketPair(bytes32 ammId_, address fromAsset_, address toAsset_, address facilitatorAsset_) external override onlyOwner {
        require(fromAsset_ != address(0) && toAsset_ != address(0), "MS:ZERO_ADDRESS");
        require(_marketRouters[ammId_] != address(0), "MS:MARKET_PLACE_NOT_EXISTS");
        _ammPath[ammId_][fromAsset_][toAsset_] = facilitatorAsset_;
        emit MarketPairAdded(ammId_, fromAsset_, toAsset_, facilitatorAsset_); 
    } 

    function addMarketPlace(bytes32 ammId_, address router_) external override onlyOwner {
        require(router_ != address(0), "MS:ZERO_ADDRESS");
        require(_marketRouters[ammId_] == address(0), "MS:MARKET_PLACE_ALREADY_EXISTS");
        _marketRouters[ammId_] = router_;
        emit NewMarketAdded(ammId_, router_);
    }

    /**
     * @dev Allows to add or replace the strategy.
     * @param ammId_ AMM Id. i.e bytes32("uniswap-v").
     * @param strategy_ Address of the contract that contains the logic for liquidations.
     */
    function addStrategy(bytes32 ammId_, address strategy_) external override onlyOwner {
        require(strategy_ != address(0), "MS:ZERO_ADDRESS");
        _strategy[ammId_] = strategy_;
        emit NewStrategyAdded(ammId_, strategy_);
    }

    function calcMinAmount(IMapleGlobalsLike globals_, address fromAsset_, address toAsset_, uint256 swapAmt_) external override view returns (uint256) {
        return
            swapAmt_
                 * globals_.getLatestPrice(fromAsset_)   // Convert from `fromAsset` value.
                 * 10 ** IERC20(toAsset_).decimals()     // Convert to `toAsset` decimal precision.
                 / globals_.getLatestPrice(toAsset_)     // Convert to `toAsset` value.
                 / 10 ** IERC20(fromAsset_).decimals();  // Convert from `fromAsset` decimal precision.
    }

    function setGlobals(address newGlobals_) external override onlyOwner {
        _globals = newGlobals_;
    }

    function globals() external override view returns(address) {
        return _globals;
    }

    function getAmmPath(bytes32 ammId_, address fromAsset_, address toAsset_) external override view returns(address facilitatorAsset_) {
        return _ammPath[ammId_][fromAsset_][toAsset_];
    }

    function getRouter(bytes32 ammId_) external override view returns(address router_) {
        return _marketRouters[ammId_];
    }

    function getStrategy(bytes32 ammId_) external override view returns(address strategy_) {
        return _strategy[ammId_];
    }
    
}

