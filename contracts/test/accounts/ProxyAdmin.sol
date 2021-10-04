// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ILiquidations } from "../../interfaces/ILiquidations.sol";

contract ProxyAdmin {

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function liquidations_try_skim(address target_, address asset_) external returns(bool ok) {
        (ok,) = target_.call(abi.encodeWithSelector(ILiquidations.skim.selector, asset_));
    }

    /************************/
    /*** Direct Functions ***/
    /************************/

    function liquidations_skim(address target_, address asset_) external {
        ILiquidations(target_).skim(asset_);
    }

}