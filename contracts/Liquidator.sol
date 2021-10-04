// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper, IERC20 } from "../modules/erc20-helper/src/ERC20Helper.sol";

interface IAuctioneer {

    function getExpectedAmount(uint256 collateralAmount_) external view returns(uint256 fundsAmount_);

}

contract Liquidator {
    address public collateralAsset;
    address public destination;
    address public auctioneer;
    address public fundsAsset;
    address public owner;

    constructor(address owner_, address collateralAsset_, address fundsAsset_, address destination_, address auctioneer_) {
        owner           = owner_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
        destination     = destination_;
        auctioneer      = auctioneer_;
    }

    function setAuctioneer(address auctioneer_) external {
        require(msg.sender == owner);
        auctioneer = auctioneer_;
    }

    function setDestination(address destination_) external {
        require(msg.sender == owner);
        destination = destination_;
    }

    function liquidatePortion(uint256 swapAmount_, bytes calldata data_) external {
        ERC20Helper.transfer(collateralAsset, msg.sender, swapAmount_);

        msg.sender.call(data_);

        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, destination, IAuctioneer(auctioneer).getExpectedAmount(swapAmount_)));
    }

}
