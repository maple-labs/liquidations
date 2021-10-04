// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { SlotManipulatable } from "../modules/proxy-factory/contracts/SlotManipulatable.sol";

contract LiquidationsStateReader is SlotManipulatable {

    /// @dev Storage slot with the address of the Market state contract. This is the keccak-256 hash of "MARKET_STATE_SLOT".
    bytes32 internal constant MARKET_STATE_SLOT = 0x31f1e52d01858b994f2d2050d769a96de7b00b3f06a97361bfd1c12da19a4434;

    /// @dev Storage slot with the address of the Market state contract. This is the keccak-256 hash of "PROXY_ADMIN_STATE_SLOT".
    bytes32 internal constant PROXY_ADMIN_STATE_SLOT = 0x96c266e07186ab3aacee9fd2d71e8d152bce9b2022c0ef3565b213cba06c64d1;

    function getMarketStateAddress() internal view returns(address) {
        return address(uint160(uint256(_getSlotValue(MARKET_STATE_SLOT))));
    }

    function getProxyAdminAddress() internal view returns(address) {
        return address(uint160(uint256(_getSlotValue(PROXY_ADMIN_STATE_SLOT))));
    }
    
}