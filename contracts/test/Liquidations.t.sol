// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { MarketStateOwner } from "./accounts/MarketStateOwner.sol";
import { ProxyAdmin }       from "./accounts/ProxyAdmin.sol";

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
    ProxyAdmin        proxyAdmin;

    function setUp() external {
        mapleGlobals      = new MapleGlobalsLike();
        marketStateOwner  = new MarketStateOwner();
        proxyAdmin        = new ProxyAdmin();
        marketState       = new MarketState(address(mapleGlobals), address(marketStateOwner));
        liquidations      = new Liquidations(address(marketState), address(proxyAdmin));
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
        // Create a loan
        Loan loan = new Loan(collateralAmount_);
        _mintCollateral(address(loan), collateralAmount_);
        loan.transferCollateral(address(liquidations), WETH);
        
        (uint256 amountLiquidated,) = IStrategy(address(liquidations)).triggerDefaultWithAmmId(bytes32("UniswapV2"), address(loan), collateralAmount_, WETH, USDC);
        assertEq(amountLiquidated, collateralAmount_, "Incorrect amount get liquidated");
    }

    function test_triggerDefaultWithAmmId_inMultipleTranches(uint256 collateralAmount_) external {
        collateralAmount_ = constrictToRange(collateralAmount_, 1 ether, 500 ether);
        // Create a loan
        Loan loan = new Loan(collateralAmount_);
        _mintCollateral(address(loan), collateralAmount_);
        loan.transferCollateral(address(liquidations), WETH);

        // Liquidations 1 -- liquidate 1/3 
        (uint256 amountLiquidated,) = IStrategy(address(liquidations)).triggerDefaultWithAmmId(bytes32("UniswapV2"), address(loan), collateralAmount_ / 3, WETH, USDC);
        assertEq(amountLiquidated, collateralAmount_ / 3, "Incorrect amount get liquidated");

        // Liquidations 2 -- liquidate 2/3 
        (amountLiquidated,) = IStrategy(address(liquidations)).triggerDefaultWithAmmId(bytes32("UniswapV2"), address(loan), 2 * collateralAmount_ / 3, WETH, USDC);
        assertEq(amountLiquidated, 2 * collateralAmount_ / 3, "Incorrect amount get liquidated");

        // Liquidations 2 -- liquidate 2/3 
        try IStrategy(address(liquidations)).triggerDefaultWithAmmId(bytes32("UniswapV2"), address(loan), collateralAmount_ / 3, WETH, USDC) {
            revert("Should not liquidate");
        } catch Error(string memory error_) {
            assertEq(error_, "UniswapV2Strategy:INSUFFICIENT_COLLATERAL", "Incorrect revert string");
        }
    }

}