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

    function _getStrategyImplementation() internal virtual returns (address strategy_) {
        require(_getSig(msg.data) == IStrategy.triggerDefaultWithAmmId.selector, "LP:INVALID_METHOD_CALL");
        (bytes32 ammId_,,,,) = abi.decode(msg.data, (bytes32, uint256, address, address, address));
        strategy_ = IMarketState(getMarketStateAddress()).getStrategy(ammId_);
        require(strategy_ != address(0), "LP:INVALID_STRATEGY");
    }

    function _fallback() internal override virtual {
        _delegate(_getStrategyImplementation());
    }

    function _getSig(bytes memory data_) internal pure returns(bytes4 sig_) {
        uint len = data_.length < 4 ? data_.length : 4;
        for (uint256 i = 0; i < len; i++) {
          sig_ |= bytes4(data_[i] & 0xFF) >> (i * 8);
        }
        return sig_;
    }
    
}