// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IERC20 }      from "../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";

import { ILender }            from "./interfaces/ILender.sol";
import { IUniswapRouterLike } from "./interfaces/Interfaces.sol";

contract UniswapV2Strategy {

    address public constant UNISWAP_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    using ERC20Helper for address;

    enum Action { NORMAL, OTHER }

    /// @dev ERC-3156 Flash loan callback 
    /// TODO: Check if we need to add anything else here
    function onFlashLoan(address initiator_, bytes calldata data_) external returns (bytes32) {
        // require(msg.sender == address(lender), "FlashBorrower: Untrusted lender"); TODO: Do we need this if this contract will never hold a balance?
        require(initiator_ == address(this), "FlashBorrower: Untrusted loan initiator");

        (Action action) = abi.decode(data_, (Action));
        return keccak256("ERC3156FlashBorrower.MapleFinance.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrowLiquidation(
        address lender_, 
        uint256 swapAmount_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_,
        address profitDestination_
    ) 
        public 
    {
        bytes memory data = abi.encode(Action.NORMAL);

        uint256 repaymentAmount = ILender(lender_).getReturnAmount(swapAmount_);

        IERC20(fundsAsset_).approve(lender_, uint256(0));       // TODO: Do we need to set to zero here?
        IERC20(fundsAsset_).approve(lender_, repaymentAmount);  // TODO: ERC20Helper

        ILender(lender_).flashLoanLiquidation(
            address(this), 
            swapAmount_, 
            data, 
            abi.encodeWithSelector(
                this.swap.selector, 
                swapAmount_, 
                repaymentAmount, 
                collateralAsset_, 
                middleAsset_, 
                fundsAsset_,
                profitDestination_
            )
        );
    }

    /// @dev Assumption - Before calling this function liquidator would transfer all the collateral to Liquidator (i.e proxy) contract.
    function swap(
        uint256 swapAmount_,
        uint256 minReturnAmount_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_,
        address profitDestination_
    )
        external
    {
        // Get the liquidation amount from loan.
        require(IERC20(collateralAsset_).balanceOf(address(this)) == swapAmount_, "UniswapV2Strategy:WRONG_COLLATERAL_AMT");
        
        // if (collateralAsset_ == liquidityAsset_ || amount_ == uint256(0)); // TODO: Think about this case

        IERC20(collateralAsset_).approve(UNISWAP_ROUTER_V2, uint256(0));   // TODO: Do we need to set to zero here?
        IERC20(collateralAsset_).approve(UNISWAP_ROUTER_V2, swapAmount_);  // TODO: ERC20Helper

        bool hasMiddleAsset = middleAsset_ != fundsAsset_ && middleAsset_ != address(0);

        address[] memory path = new address[](hasMiddleAsset ? 3 : 2);

        path[0] = address(collateralAsset_);
        path[1] = hasMiddleAsset ? middleAsset_ : fundsAsset_;

        if (hasMiddleAsset) path[2] = fundsAsset_;

        // Swap collateralAsset for Liquidity Asset.
        IUniswapRouterLike(UNISWAP_ROUTER_V2).swapExactTokensForTokens(
            swapAmount_,
            minReturnAmount_,
            path,
            address(this),
            block.timestamp
        );

        IERC20(fundsAsset_).transfer(profitDestination_, IERC20(fundsAsset_).balanceOf(address(this)) - minReturnAmount_);  // TODO: ERC20Helper
    }

}

