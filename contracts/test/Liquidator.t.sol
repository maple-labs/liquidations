// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { TestUtils, StateManipulations } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                        from "../../modules/erc20-helper/lib/erc20/src/interfaces/IERC20.sol";

import { IOracle, IUniswapRouterLike } from "../interfaces/Interfaces.sol";

import { Liquidator }        from "../Liquidator.sol";
import { UniswapV2Strategy } from "../UniswapV2Strategy.sol";
import { SushiswapStrategy } from "../SushiswapStrategy.sol";

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

contract AuctioneerLike {

    address public owner;
    address public collateralAsset;
    address public fundsAsset;
    address public globals;
    uint256 public allowedSlippage;
    uint256 public minRatio;

    constructor(address globals_, address collateralAsset_, address fundsAsset_, uint256 allowedSlippage_, uint256 minRatio_) {
        owner           = msg.sender;
        globals         = globals_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
        allowedSlippage = allowedSlippage_;
        minRatio        = minRatio_;
    }

    function getExpectedAmount(uint256 swapAmount_) public view returns (uint256 returnAmount_) {
        uint256 oracleAmount = 
            swapAmount_
                * MapleGlobalsLike(globals).getLatestPrice(collateralAsset)  // Convert from `fromAsset` value.
                * 10 ** IERC20(fundsAsset).decimals()                        // Convert to `toAsset` decimal precision.
                * (10_000 - allowedSlippage)                                 // Multiply by allowed slippage basis points
                / MapleGlobalsLike(globals).getLatestPrice(fundsAsset)       // Convert to `toAsset` value.
                / 10 ** IERC20(collateralAsset).decimals()                   // Convert from `fromAsset` decimal precision.
                / 10_000;                                                    // Divide basis points for slippage
        
        uint256 minRatioAmount = swapAmount_ * minRatio / 10 ** IERC20(collateralAsset).decimals();

        return oracleAmount > minRatioAmount ? oracleAmount : minRatioAmount;
    }
}

// Contract to perform fake arbitrage transactions to prop price back up
contract Rebalancer is StateManipulations {

    function swap(
        address router_,
        uint256 amountOut_,
        uint256 amountInMax_,
        address fromAsset_,
        address middleAsset_,
        address toAsset_
    )
        external
    {
        IERC20(fromAsset_).approve(router_, amountInMax_);  // TODO: ERC20Helper

        bool hasMiddleAsset = middleAsset_ != toAsset_ && middleAsset_ != address(0);

        address[] memory path = new address[](hasMiddleAsset ? 3 : 2);

        path[0] = address(fromAsset_);
        path[1] = hasMiddleAsset ? middleAsset_ : toAsset_;

        if (hasMiddleAsset) path[2] = toAsset_;

        IUniswapRouterLike(router_).swapTokensForExactTokens(
            amountOut_,
            amountInMax_,
            path,
            address(this),
            block.timestamp
        );
    }

}

contract LiquidatorUniswapTest is TestUtils, StateManipulations {

    address public constant UNISWAP_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant USDC              = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_ORACLE       = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant WETH              = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WETH_ORACLE       = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    IERC20 constant usdc = IERC20(USDC);
    IERC20 constant weth = IERC20(WETH);

    address constant profitDestination = address(111);  // Address that collects profits from swaps

    AuctioneerLike    auctioneer;
    AuctioneerLike    benchmarkAuctioneer;
    Liquidator        benchmarkLiquidator;
    Liquidator        liquidator;
    MapleGlobalsLike  globals;
    Rebalancer        rebalancer;
    UniswapV2Strategy uniswapV2Strategy;

    function setUp() external {
        globals = new MapleGlobalsLike();

        auctioneer          = new AuctioneerLike(address(globals), WETH, USDC, 200,    2_000 * 10 ** 6);  // 2% slippage allowed from market price
        benchmarkAuctioneer = new AuctioneerLike(address(globals), WETH, USDC, 10_000, 0);                // 100% slippage with zero ratio to benchmark against atomic liquidation
        benchmarkLiquidator = new Liquidator(address(this),    WETH, USDC, address(benchmarkAuctioneer));
        liquidator          = new Liquidator(address(globals), WETH, USDC, address(auctioneer));
        uniswapV2Strategy   = new UniswapV2Strategy();
        rebalancer          = new Rebalancer();

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    function test_liquidator_uniswapV2Strategy() public {
        erc20_mint(WETH, 3, address(liquidator),          1_000 ether);
        erc20_mint(WETH, 3, address(benchmarkLiquidator), 1_000 ether);
        erc20_mint(USDC, 9, address(rebalancer),          type(uint256).max);

        uint256 returnAmount = liquidator.getExpectedAmount(1_000 ether);

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

        uint256 returnAmount1 = liquidator.getExpectedAmount(483 ether);
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

        rebalancer.swap(UNISWAP_ROUTER_V2, 483 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        uint256 returnAmount2 = liquidator.getExpectedAmount(250 ether);
        assertEq(returnAmount2, 825_373_820446);  // $825k

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 250 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        267 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 6_047_538289);

        /**************************/
        /*** Third Liquidation ***/
        /**************************/

        rebalancer.swap(UNISWAP_ROUTER_V2, 250 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        uint256 returnAmount3 = liquidator.getExpectedAmount(267 ether);
        assertEq(returnAmount3, 881_499_240236);  // $881k

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 267 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        0 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2 + returnAmount3);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 12_066_770467);

        /*****************************/
        /*** Benchmark Liquidation ***/
        /*****************************/

        rebalancer.swap(UNISWAP_ROUTER_V2, 267 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 1000 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        uniswapV2Strategy.flashBorrowLiquidation(address(benchmarkLiquidator), 1000 ether, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 3_250_485_553902);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        assertEq(3_250_485_553902 * 10 ** 18 / (returnAmount1 + returnAmount2 + returnAmount3), 0.984549507562998447 ether);  // ~ 1.5% savings on $3.3m liquidation, will do larger liquidations in another test
    }

    function test_liquidator_uniswapV2Strategy_largeLiquidation() public {
        erc20_mint(WETH, 3, address(liquidator),          100_000 ether);  // ~$340m to liquidate
        erc20_mint(WETH, 3, address(benchmarkLiquidator), 100_000 ether);
        erc20_mint(USDC, 9, address(rebalancer),          type(uint256).max);

        assertEq(weth.balanceOf(address(liquidator)),        100_000 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        /*************************************************/
        /*** Peicewise Liquidations (223 liquidations) ***/
        /*************************************************/

        while(weth.balanceOf(address(liquidator)) > 0) {
            uint256 swapAmount = weth.balanceOf(address(liquidator)) > 450 ether ? 450 ether : weth.balanceOf(address(liquidator));  // Stay within 2% slippage

            uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), swapAmount, WETH, address(0), USDC, profitDestination);

            rebalancer.swap(UNISWAP_ROUTER_V2, swapAmount, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 
        }

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        330_149_528_178444);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 3_410_700_223339);

        /*****************************/
        /*** Benchmark Liquidation ***/
        /*****************************/

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 100_000 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        uniswapV2Strategy.flashBorrowLiquidation(address(benchmarkLiquidator), 100_000 ether, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 82_867_335_808521);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        assertEq(uint256(82_867_335_808521) * 10 ** 18 / uint256(330_149_528_178444), 0.250999407043621948 ether);  // ~75% savings on $340m liquidation
    }

}

contract LiquidatorSushiswapTest is TestUtils, StateManipulations {

    address public constant SUSHISWAP_ROUTER_V2 = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address public constant USDC                = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_ORACLE         = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant WETH                = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WETH_ORACLE         = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    IERC20 constant usdc = IERC20(USDC);
    IERC20 constant weth = IERC20(WETH);

    address constant profitDestination = address(111);  // Address that collects profits from swaps

    AuctioneerLike    auctioneer;
    AuctioneerLike    benchmarkAuctioneer;
    Liquidator        benchmarkLiquidator;
    Liquidator        liquidator;
    MapleGlobalsLike  globals;
    Rebalancer        rebalancer;
    SushiswapStrategy sushiswapStrategy;

    function setUp() external {
        globals = new MapleGlobalsLike();

        auctioneer          = new AuctioneerLike(address(globals), WETH, USDC, 200,    2_000 * 10 ** 6);  // 2% slippage allowed from market price
        benchmarkAuctioneer = new AuctioneerLike(address(globals), WETH, USDC, 10_000, 0);                // 100% slippage with zero ratio to benchmark against atomic liquidation
        benchmarkLiquidator = new Liquidator(address(this),    WETH, USDC, address(benchmarkAuctioneer));
        liquidator          = new Liquidator(address(globals), WETH, USDC, address(auctioneer));
        sushiswapStrategy   = new SushiswapStrategy();
        rebalancer          = new Rebalancer();

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    function test_liquidator_sushiswapStrategy_sii() public {
        erc20_mint(WETH, 3, address(liquidator),          2_000 ether);
        erc20_mint(WETH, 3, address(benchmarkLiquidator), 2_000 ether);
        erc20_mint(USDC, 9, address(rebalancer),          type(uint256).max);

        uint256 returnAmount = liquidator.getExpectedAmount(2_000 ether);

        assertEq(returnAmount, 6_602_990_563570);  // $6.6m

        assertEq(weth.balanceOf(address(liquidator)),        2_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        // Try liquidating amount that is above slippage requirements
        try sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 1000 ether, WETH, address(0), USDC, profitDestination) { fail(); } catch {}

        /*************************/
        /*** First Liquidation ***/
        /*************************/

        uint256 returnAmount1 = liquidator.getExpectedAmount(950 ether);
        assertEq(returnAmount1, 3_136_420_517695);  // $1.59m

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        1050 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 2_366_149563);

        /**************************/
        /*** Second Liquidation ***/
        /**************************/

        rebalancer.swap(SUSHISWAP_ROUTER_V2, 950 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        uint256 returnAmount2 = liquidator.getExpectedAmount(950 ether);
        assertEq(returnAmount2, 3_136_420_517695);  // $825k

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        100 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 5_039_959806);

        /**************************/
        /*** Third Liquidation ***/
        /**************************/

        rebalancer.swap(SUSHISWAP_ROUTER_V2, 950 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        uint256 returnAmount3 = liquidator.getExpectedAmount(100 ether);
        assertEq(returnAmount3, 330_149_528178);  // $881k

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 100 ether, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        0 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2 + returnAmount3);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 10_233_419098);

        /*****************************/
        /*** Benchmark Liquidation ***/
        /*****************************/

        rebalancer.swap(SUSHISWAP_ROUTER_V2, 50 ether, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 2_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        sushiswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 2_000 ether, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 6_481_487_535049);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(6_481_487_535049 * 10 ** 18 / (returnAmount1 + returnAmount2 + returnAmount3), 0.981598788102258853 ether);  // ~ 1.9% savings on $6.6m liquidation, will do larger liquidations in another test
    }

    function test_liquidator_sushiswapStrategy_largeLiquidation() public {
        erc20_mint(WETH, 3, address(liquidator),          100_000 ether);  // ~$340m to liquidate
        erc20_mint(WETH, 3, address(benchmarkLiquidator), 100_000 ether);
        erc20_mint(USDC, 9, address(rebalancer),          type(uint256).max);

        assertEq(weth.balanceOf(address(liquidator)),        100_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        /*************************************************/
        /*** Peicewise Liquidations (223 liquidations) ***/
        /*************************************************/

        while(weth.balanceOf(address(liquidator)) > 0) {
            uint256 swapAmount = weth.balanceOf(address(liquidator)) > 450 ether ? 450 ether : weth.balanceOf(address(liquidator));  // Stay within 2% slippage

            sushiswapStrategy.flashBorrowLiquidation(address(liquidator), swapAmount, WETH, address(0), USDC, profitDestination);

            rebalancer.swap(SUSHISWAP_ROUTER_V2, swapAmount, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up 
        }

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        330_149_528_178444);  // Note that this is the exact same as the uniswap liquidation test, because the return amounts are the same.
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 4_835_774_802838);

        /*****************************/
        /*** Benchmark Liquidation ***/
        /*****************************/

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 100_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        sushiswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 100_000 ether, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 123_850_243_565569);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(uint256(123_850_243_565569) * 10 ** 18 / uint256(330_149_528_178444), 0.375133789373851917 ether);  // ~63% savings on $340m liquidation
    }

}

