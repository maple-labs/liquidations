// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Proxy }               from "../modules/oz-contracts/contracts/proxy/Proxy.sol";
import { ERC20Helper, IERC20 } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { LiquidationsStateReader } from "./LiquidationsStateReader.sol";

import { IMarketState }  from "./interfaces/IMarketState.sol";
import { IStrategy }     from "./interfaces/IStrategy.sol";

contract Liquidations is Proxy, LiquidationsStateReader {

    constructor(address marketState_, address proxyAdmin_) {
        require(marketState_ != address(0) && proxyAdmin_ != address(0), "L:ZERO_ADDRESS");
        _setSlotValue(MARKET_STATE_SLOT, bytes32(uint256(uint160(marketState_))));
        _setSlotValue(PROXY_ADMIN_STATE_SLOT, bytes32(uint256(uint160(proxyAdmin_))));
    }

    modifier onlyProxyAdmin() {
        require(msg.sender == getProxyAdminAddress(), "L:INVALID_PROXY_AMIN");
        _;
    }

    ///@dev Allowed proxy admin to skimmed the funds from the proxy.
    function skim(address asset_) external onlyProxyAdmin {
        ERC20Helper.transfer(asset_, getProxyAdminAddress(), IERC20(asset_).balanceOf(address(this)));
    }

    function _implementation() internal view override returns (address) {
        return IMarketState(getMarketStateAddress()).getStrategy(bytes32("UniswapV2"));
    }

    function _getStrategyImplementation() internal view returns (address strategy_) {
        (bytes4 sig_, bytes32 ammId_,,,,) = _abiDecodeTriggerDefaultWithAmmId(msg.data);
        require(sig_ == IStrategy.triggerDefaultWithAmmId.selector, "L:INVALID_METHOD_CALL");
        strategy_ = IMarketState(getMarketStateAddress()).getStrategy(ammId_);
        require(strategy_ != address(0), "L:INVALID_STRATEGY");
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