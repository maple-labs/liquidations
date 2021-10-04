// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Proxy } from "../modules/oz-contracts/contracts/proxy/Proxy.sol";

import { LiquidationsStateReader } from "./LiquidationsStateReader.sol";

import { IMarketState }  from "./interfaces/IMarketState.sol";
import { IStrategy }     from "./interfaces/IStrategy.sol";

contract Liquidations is Proxy, LiquidationsStateReader {

    constructor(address marketState_) {
        require(marketState_ != address(0), "LP:ZERO_ADDRESS");
        _setSlotValue(MARKET_STATE_SLOT, bytes32(uint256(uint160(marketState_))));
    }

    function _implementation() internal view override returns (address) {
        return IMarketState(getMarketStateAddress()).getStrategy(bytes32("UniswapV2"));
    }

    function _getStrategyImplementation() internal view returns (address strategy_) {
        (bytes4 sig_, bytes32 ammId_,,,,) = _abiDecodeTriggerDefaultWithAmmId(msg.data);
        require(sig_ == IStrategy.triggerDefaultWithAmmId.selector, "LP:INVALID_METHOD_CALL");
        strategy_ = IMarketState(getMarketStateAddress()).getStrategy(ammId_);
        require(strategy_ != address(0), "LP:INVALID_STRATEGY");
    }

    function _fallback() internal override virtual {
        _delegate(_getStrategyImplementation());
    }

    function _abiDecodeTriggerDefaultWithAmmId(
        bytes memory _data
    ) 
        internal 
        pure 
        returns(
            bytes4 sig,
            bytes32 ammId_,
            address loan_,
            uint256 amount_,
            address collateralAsset_,
            bytes32 liquidityAsset_
        )
    {
        assembly {
            sig := mload(add(_data, add(0x20, 0)))
            ammId_ := mload(add(_data, 36))
            loan_ := mload(add(_data, 68))
            amount_ := mload(add(_data, 100))
            collateralAsset_ := mload(add(_data, 132))
            liquidityAsset_ := mload(add(_data, 164))
        }
    }
    
}