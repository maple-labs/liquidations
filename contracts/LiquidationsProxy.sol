// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Proxy } from "../modules/proxy-factory/contracts/Proxy.sol";
import { Proxied } from "../modules/proxy-factory/contracts/Proxied.sol";

contract LiquidationsProxy is Proxy, Proxied {

    receive() payable external {}
    
}