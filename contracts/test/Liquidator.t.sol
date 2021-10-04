// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { TestUtils, StateManipulations } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                        from "../../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";

import { IOracle, IUniswapRouterLike } from "../interfaces/Interfaces.sol";

import { Liquidator }        from "../Liquidator.sol";
import { UniswapV2Strategy } from "../UniswapV2Strategy.sol";

contract MapleGlobalsLike {

    mapping (address => address) public oracleFor;

    function getLatestPrice(address asset) external view returns (uint256) {
        (, int256 price,,,) = IOracle(oracleFor[asset]).latestRoundData();
        return uint256(price);
    }

    function setPriceOracle(address asset, address oracle) external {
        oracleFor[asset] = oracle;
    }

}

// Contract to perform fake arbitrage transactions to prop price back up
contract UniswapRebalancer is StateManipulations {

    address public constant UNISWAP_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function swap(
        uint256 amountOut_,
        uint256 amountInMax_,
        address fromAsset_,
        address middleAsset_,
        address toAsset_
    )
        external
    {
        IERC20(fromAsset_).approve(UNISWAP_ROUTER_V2, amountInMax_);  // TODO: ERC20Helper

        bool hasMiddleAsset = middleAsset_ != toAsset_ && middleAsset_ != address(0);

        address[] memory path = new address[](hasMiddleAsset ? 3 : 2);

        path[0] = address(fromAsset_);
        path[1] = hasMiddleAsset ? middleAsset_ : toAsset_;

        if (hasMiddleAsset) path[2] = toAsset_;

        IUniswapRouterLike(UNISWAP_ROUTER_V2).swapTokensForExactTokens(
            amountOut_,
            amountInMax_,
            path,
            address(this),
            block.timestamp
        );
    }

}

contract LiquidatorUniswapTest is TestUtils, StateManipulations {

    address public constant WETH        = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC        = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDC_ORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);

    address constant profitDestination = address(111);  // Address that collects profits from swaps

    Liquidator        benchmarkLiquidator;
    Liquidator        liquidator;
    MapleGlobalsLike  globals;
    UniswapV2Strategy uniswapV2Strategy;
    UniswapRebalancer rebalancer;

    function setUp() external {
        globals             = new MapleGlobalsLike();
        benchmarkLiquidator = new Liquidator(address(globals), WETH, USDC, 10_000);  // 100% slippage to benchmark against atomic liquidation
        liquidator          = new Liquidator(address(globals), WETH, USDC, 200);     // 2% slippage allowed from market price
        uniswapV2Strategy   = new UniswapV2Strategy();
        rebalancer          = new UniswapRebalancer();

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    function test_liquidator_uniswapV2Strategy() public {
        erc20_mint(WETH, 3, address(liquidator),          1_000 ether);
        erc20_mint(WETH, 3, address(benchmarkLiquidator), 1_000 ether);
        erc20_mint(USDC, 9, address(rebalancer),          type(uint256).max);

        uint256 returnAmount = liquidator.getReturnAmount(1_000 ether);

        assertEq(returnAmount, 3_301_495_281785);  // $3.3m

        assertEq(weth.balanceOf(address(liquidator)),        1_000 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        // Try liquidating amount that is above slippage requirements
        try uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 485 ether, WETH, address(0), USDC, profitDestination) { fail(); } catch {}

        /*************************/
        /*** First Liquidation ***/
        /*************************/

        uint256 returnAmount1 = liquidator.getReturnAmount(483 ether);
        assertEq(returnAmount1, 1_594_622_221102);  // $1.59m

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 483 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        517 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 13_001643);

        /**************************/
        /*** Second Liquidation ***/
        /**************************/

        rebalancer.swap(517 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        uint256 returnAmount2 = liquidator.getReturnAmount(250 ether);
        assertEq(returnAmount2, 825_373_820446);  // $825k

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 250 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        267 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 7_815_252668);

        /**************************/
        /*** Third Liquidation ***/
        /**************************/

        rebalancer.swap(250 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        uint256 returnAmount3 = liquidator.getReturnAmount(267 ether);
        assertEq(returnAmount3, 881_499_240236);  // $881k

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 267 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        0 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2 + returnAmount3);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 15_721_048236);

        /*****************************/
        /*** Benchmark Liquidation ***/
        /*****************************/

        rebalancer.swap(267 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 1000 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        uniswapV2Strategy.flashBorrowLiquidation(address(benchmarkLiquidator), 1000 ether, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 3_257_318_855716);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        assertEq(3_257_318_855716 * 10 ** 18 / (returnAmount1 + returnAmount2 + returnAmount3), 0.986619267241803001 ether);  // ~ 1.5% savings on $3.3m liquidation, will do larger liquidations in another test
    }

}

