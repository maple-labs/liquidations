// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { MarketStateOwner } from "./accounts/MarketStateOwner.sol";

import { IOracle }   from "../interfaces/Interfaces.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

import { TestUtils, StateManipulations } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                        from "../../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";

import { Liquidations }      from "../Liquidations.sol";
import { MarketState }       from "../MarketState.sol";
import { UniswapV2Strategy } from "../UniswapV2Strategy.sol";

contract MapleGlobalsLike {

    mapping (address => address) public oracleFor;

    function maxSwapSlippage() external pure returns(uint256) {
        return 1000;
    }

    function getLatestPrice(address asset) external view returns (uint256) {
        (, int256 price,,,) = IOracle(oracleFor[asset]).latestRoundData();
        return uint256(price);
    }

    function setPriceOracle(address asset, address oracle) external {
        oracleFor[asset] = oracle;
    }

}

contract Loan {

    uint256 public collateral;

    constructor(uint256 collateral_) {
        collateral = collateral_;
    }

    function transferCollateral(address to_, address collateralAsset_) external {
        IERC20(collateralAsset_).transfer(to_, collateral);
    }
    
}

contract LiquidationsUniswapTest is TestUtils, StateManipulations {

    address public constant WETH              = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC              = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant UNISWAP_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant SUSHISWAP_ROUTER  = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address public constant WETH_ORACLE       = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDC_ORACLE       = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    MapleGlobalsLike  mapleGlobals;
    Liquidations      liquidations;
    MarketStateOwner  marketStateOwner;
    MarketState       marketState;
    UniswapV2Strategy uniswapV2Strategy;

    function setUp() external {
        mapleGlobals      = new MapleGlobalsLike();
        marketStateOwner  = new MarketStateOwner();
        marketState       = new MarketState(address(mapleGlobals), address(marketStateOwner));
        liquidations      = new Liquidations(address(marketState));
        uniswapV2Strategy = new UniswapV2Strategy();

        mapleGlobals.setPriceOracle(WETH, WETH_ORACLE);
        mapleGlobals.setPriceOracle(USDC, USDC_ORACLE);

        // Add market place & pair.
        marketStateOwner.marketState_addMarketPlace(address(marketState), bytes32("UniswapV2"), UNISWAP_ROUTER_V2);
        marketStateOwner.marketState_addMarketPlace(address(marketState), bytes32("Sushiswap"), SUSHISWAP_ROUTER);

        marketStateOwner.marketState_addMarketPair(address(marketState), bytes32("UniswapV2"), WETH, USDC, address(0));
        marketStateOwner.marketState_addMarketPair(address(marketState), bytes32("Sushiswap"), WETH, USDC, address(0));

        marketStateOwner.marketState_addStrategy(address(marketState), bytes32("UniswapV2"), address(uniswapV2Strategy));
    }

    function _mintCollateral(address to_, uint256 amount_) internal view {
        erc20_mint(WETH, 3, to_, amount_);
    } 

    function test_triggerDefault_withUniswapV2(uint256 collateralAmount_) external {
        collateralAmount_ = constrictToRange(collateralAmount_, 1 ether, 500 ether);
        collateralAmount_ = 10 ether;
        // Create a loan
        Loan loan = new Loan(collateralAmount_);
        _mintCollateral(address(loan), collateralAmount_);
        loan.transferCollateral(address(liquidations), WETH);
        
        (uint256 amountLiquidated,) = IStrategy(address(liquidations)).triggerDefaultWithAmmId(bytes32("UniswapV2"), address(loan), collateralAmount_, WETH, USDC);
        assertEq(amountLiquidated, collateralAmount_, "Incorrect amount get liquidated");
    }

}