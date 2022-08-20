// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }             from "../../modules/erc20/contracts/interfaces/IERC20.sol";
import { MockERC20 }          from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { Liquidator }        from "../Liquidator.sol";
import { SushiswapStrategy } from "../SushiswapStrategy.sol";
import { UniswapV2Strategy } from "../UniswapV2Strategy.sol";

import { Owner } from "./accounts/Owner.sol";

import { AuctioneerMock, EmptyContract, FailApproveERC20, MapleGlobalsMock, Rebalancer, ReentrantLiquidator } from "./mocks/Mocks.sol";

contract LiquidatorConstructorTest is TestUtils {

    address auctioneer;
    address collateralAsset;
    address destination;
    address emptyContract;
    address failingErc20;
    address fundsAsset;
    address globals;
    address owner;

    function setUp() external {
        auctioneer      = address(new Address());
        collateralAsset = address(new MockERC20("Collateral", "COLLATERAL", 18));
        destination     = address(new Address());
        emptyContract   = address(new EmptyContract());
        failingErc20    = address(new FailApproveERC20());
        fundsAsset      = address(new MockERC20("Funds", "FUNDS", 18));
        globals         = address(new MapleGlobalsMock());
        owner           = address(new Address());
    }

    function test_constructor_zeroOwner() external {
        vm.expectRevert("LIQ:C:INVALID_OWNER");
        new Liquidator(address(0), collateralAsset, fundsAsset, auctioneer, destination, globals);
    }

    function test_constructor_zeroDestination() external {
        vm.expectRevert("LIQ:C:INVALID_DEST");
        new Liquidator(owner, collateralAsset, fundsAsset, auctioneer, address(0), globals);
    }

    function test_constructor_zeroGlobals() external {
        vm.expectRevert("LIQ:C:INVALID_GLOBALS");
        new Liquidator(owner, collateralAsset, fundsAsset, auctioneer, destination, address(0));
    }

    function test_constructor_badApproveCollateralAsset() external {
        vm.expectRevert("LIQ:C:INVALID_C_APPROVE");
        new Liquidator(owner, failingErc20, fundsAsset, auctioneer, destination, globals);
    }

    function test_constructor_badApproveFundsAsset() external {
        vm.expectRevert("LIQ:C:INVALID_F_APPROVE");
        new Liquidator(owner, collateralAsset, failingErc20, auctioneer, destination, globals);
    }

    function test_constructor_success() external {
        Liquidator liquidator = new Liquidator(owner, collateralAsset, fundsAsset, auctioneer, destination, globals);

        assertEq(liquidator.owner(),           owner);
        assertEq(liquidator.collateralAsset(), collateralAsset);
        assertEq(liquidator.fundsAsset(),      fundsAsset);
        assertEq(liquidator.auctioneer(),      auctioneer);
        assertEq(liquidator.globals(),         globals);

        assertEq(MockERC20(collateralAsset).allowance(address(liquidator), destination), type(uint256).max);

        assertEq(MockERC20(fundsAsset).allowance(address(liquidator), destination), type(uint256).max);
    }

}

contract LiquidatorAdminTest is TestUtils {

    address internal auctioneer = address(111);
    address internal globals    = address(new MapleGlobalsMock());

    Liquidator internal liquidator;
    MockERC20  internal collateralAsset;
    MockERC20  internal fundsAsset;
    Owner      internal owner;
    Owner      internal notOwner;

    function setUp() external {
        collateralAsset = new MockERC20("CollateralAsset", "CA", 18);
        fundsAsset      = new MockERC20("FundsAsset",      "FA", 18);
        notOwner        = new Owner();
        owner           = new Owner();
        liquidator      = new Liquidator(address(owner), address(collateralAsset), address(fundsAsset), auctioneer, address(1), globals);
    }

    function test_setAuctioneer() external {
        assertEq(liquidator.auctioneer(), address(111));
        assertEq(liquidator.owner(),      address(owner));

        assertTrue(!notOwner.try_liquidator_setAuctioneer(address(liquidator), address(123)));
        assertTrue(    owner.try_liquidator_setAuctioneer(address(liquidator), address(123)));

        assertEq(liquidator.auctioneer(), address(123));
    }

    function test_pullFunds() external {
        address fundsDestination = address(1);

        collateralAsset.mint(address(liquidator), 10 ether);
        fundsAsset.mint(address(liquidator),      20 ether);

        assertEq(collateralAsset.balanceOf(address(liquidator)),       10 ether);
        assertEq(collateralAsset.balanceOf(address(fundsDestination)), 0);
        assertEq(fundsAsset.balanceOf(address(liquidator)),            20 ether);
        assertEq(fundsAsset.balanceOf(address(fundsDestination)),      0);

        assertTrue(!notOwner.try_liquidator_pullFunds(address(liquidator), address(collateralAsset), address(fundsDestination), 10 ether));
        assertTrue(!notOwner.try_liquidator_pullFunds(address(liquidator), address(fundsAsset),      address(fundsDestination), 20 ether));
        assertTrue(    owner.try_liquidator_pullFunds(address(liquidator), address(collateralAsset), address(fundsDestination), 10 ether));
        assertTrue(    owner.try_liquidator_pullFunds(address(liquidator), address(fundsAsset),      address(fundsDestination), 20 ether));

        assertEq(collateralAsset.balanceOf(address(liquidator)),       0);
        assertEq(collateralAsset.balanceOf(address(fundsDestination)), 10 ether);
        assertEq(fundsAsset.balanceOf(address(liquidator)),            0);
        assertEq(fundsAsset.balanceOf(address(fundsDestination)),      20 ether);
    }

}

contract LiquidatorUniswapTest is TestUtils {

    address public constant UNISWAP_ROUTER_V2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public constant USDC              = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_ORACLE       = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    address public constant WETH              = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant WETH_ORACLE       = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    IERC20 internal constant usdc = IERC20(USDC);
    IERC20 internal constant weth = IERC20(WETH);

    address internal fundsDestination1 = address(new Address());
    address internal fundsDestination2 = address(new Address());
    address internal profitDestination = address(new Address());  // Address that collects profits from swaps

    AuctioneerMock    internal auctioneer;
    AuctioneerMock    internal benchmarkAuctioneer;
    Liquidator        internal benchmarkLiquidator;
    Liquidator        internal liquidator;
    MapleGlobalsMock  internal globals;
    Rebalancer        internal rebalancer;
    UniswapV2Strategy internal uniswapV2Strategy;

    bool locked;  // Helper state variable to avoid infinite loops when using the modifier.

    modifier assertFailureWhenPaused() {
        if (!locked) {
            locked = true;

            globals.setProtocolPaused(true);

            ( bool success, ) = address(this).call(msg.data);
            assertTrue(!success || failed, "test should have failed when paused");

            globals.setProtocolPaused(false);
        }

        _;

        locked = false;
    }

    function setUp() external {
        globals = new MapleGlobalsMock();

        auctioneer          = new AuctioneerMock(address(globals), USDC);
        benchmarkAuctioneer = new AuctioneerMock(address(globals), USDC);

        auctioneer.__setValuesFor(WETH, 200, 2_000 * 10 ** 6);  // 2% slippage allowed from market price

        benchmarkAuctioneer.__setValuesFor(WETH, 10_000, 0);  // 100% slippage allowed from market price to demonstrate actual amount taken in case of atomic liquidation

        benchmarkLiquidator = new Liquidator(address(this), WETH, USDC, address(benchmarkAuctioneer), fundsDestination2, address(globals));
        liquidator          = new Liquidator(address(this), WETH, USDC, address(auctioneer),          fundsDestination1, address(globals));
        uniswapV2Strategy   = new UniswapV2Strategy();
        rebalancer          = new Rebalancer();

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    function test_liquidator_uniswapV2Strategy() assertFailureWhenPaused public {
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
        try uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 485 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination) { fail(); } catch {}

        // Function reverts if returnAmount is larger than maxReturnAmount
        try uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 485 ether, 1, 0, WETH, address(0), USDC, profitDestination) { fail(); } catch {}

        /*************************/
        /*** First Liquidation ***/
        /*************************/

        uint256 returnAmount1 = liquidator.getExpectedAmount(483 ether);
        assertEq(returnAmount1, 1_594_622_221102);  // $1.59m

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 483 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

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

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 250 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

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

        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 267 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

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

        uniswapV2Strategy.flashBorrowLiquidation(address(benchmarkLiquidator), 1000 ether, type(uint256).max, 0, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 3_250_485_553902);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        assertEq(3_250_485_553902 * 10 ** 18 / (returnAmount1 + returnAmount2 + returnAmount3), 0.984549507562998447 ether);  // ~ 1.5% savings on $3.3m liquidation, will do larger liquidations in another test
    }

    function test_liquidator_uniswapV2Strategy_largeLiquidation() assertFailureWhenPaused public {
        erc20_mint(WETH, 3, address(liquidator),          10_000 ether);  // ~$340m to liquidate
        erc20_mint(WETH, 3, address(benchmarkLiquidator), 10_000 ether);
        erc20_mint(USDC, 9, address(rebalancer),          type(uint256).max);

        assertEq(weth.balanceOf(address(liquidator)),        10_000 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        /******************************/
        /*** Piecewise Liquidations ***/
        /******************************/

        while(weth.balanceOf(address(liquidator)) > 0) {
            uint256 swapAmount = weth.balanceOf(address(liquidator)) > 450 ether ? 450 ether : weth.balanceOf(address(liquidator));  // Stay within 2% slippage

            uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), swapAmount, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

            rebalancer.swap(UNISWAP_ROUTER_V2, swapAmount, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up
        }

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        330_149_528_17844);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 66_683_168893);

        /*****************************/
        /*** Benchmark Liquidation ***/
        /*****************************/

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 10_000 ether);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        uniswapV2Strategy.flashBorrowLiquidation(address(benchmarkLiquidator), 10_000 ether, type(uint256).max, 0, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 25_590_976_821869);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)),   0);

        assertEq(uint256(25_590_976_821869) * 10 ** 18 / uint256(330_149_528_17844), 0.775132921227060732 ether);  // ~22.4% savings on $340m liquidation
    }

}

contract LiquidatorSushiswapTest is TestUtils {

    address public constant SUSHISWAP_ROUTER_V2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address public constant USDC                = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_ORACLE         = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    address public constant WETH                = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant WETH_ORACLE         = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    IERC20 internal constant usdc = IERC20(USDC);
    IERC20 internal constant weth = IERC20(WETH);

    address internal fundsDestination1 = address(new Address());
    address internal fundsDestination2 = address(new Address());
    address internal profitDestination = address(new Address());  // Address that collects profits from swaps

    AuctioneerMock    internal auctioneer;
    AuctioneerMock    internal benchmarkAuctioneer;
    Liquidator        internal benchmarkLiquidator;
    Liquidator        internal liquidator;
    MapleGlobalsMock  internal globals;
    Rebalancer        internal rebalancer;
    SushiswapStrategy internal sushiswapStrategy;

    bool locked;  // Helper state variable to avoid infinite loops when using the modifier.

    modifier assertFailureWhenPaused() {
        if (!locked) {
            locked = true;

            globals.setProtocolPaused(true);

            ( bool success, ) = address(this).call(msg.data);
            assertTrue(!success || failed, "test should have failed when paused");

            globals.setProtocolPaused(false);
        }

        _;

        locked = false;
    }

    function setUp() external {
        globals = new MapleGlobalsMock();

        auctioneer          = new AuctioneerMock(address(globals), USDC);
        benchmarkAuctioneer = new AuctioneerMock(address(globals), USDC);

        auctioneer.__setValuesFor(WETH, 200, 2_000 * 10 ** 6);  // 2% slippage allowed from market price

        benchmarkAuctioneer.__setValuesFor(WETH, 10_000, 0);  // 100% slippage with zero ratio to benchmark against atomic liquidation

        benchmarkLiquidator = new Liquidator(address(this), WETH, USDC, address(benchmarkAuctioneer), fundsDestination2, address(globals));
        liquidator          = new Liquidator(address(this), WETH, USDC, address(auctioneer),          fundsDestination1, address(globals));
        sushiswapStrategy   = new SushiswapStrategy();
        rebalancer          = new Rebalancer();

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    function test_liquidator_sushiswapStrategy() assertFailureWhenPaused public {
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
        try sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 1000 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination) { fail(); } catch {}

        // Function reverts if returnAmount is larger than maxReturnAmount
        try sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 1000 ether, 1, 0, WETH, address(0), USDC, profitDestination) { fail(); } catch {}

        /*************************/
        /*** First Liquidation ***/
        /*************************/

        uint256 returnAmount1 = liquidator.getExpectedAmount(950 ether);
        assertEq(returnAmount1, 3_136_420_517695);  // $1.59m

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

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

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, type(uint256).max, 0, WETH,  address(0), USDC, profitDestination);

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

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 100 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

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

        sushiswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 2_000 ether, type(uint256).max, 0, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 6_481_487_535049);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(6_481_487_535049 * 10 ** 18 / (returnAmount1 + returnAmount2 + returnAmount3), 0.981598788102258853 ether);  // ~ 1.9% savings on $6.6m liquidation, will do larger liquidations in another test
    }

    function test_liquidator_sushiswapStrategy_largeLiquidation() public assertFailureWhenPaused {
        erc20_mint(WETH, 3, address(liquidator),          10_000 ether);  // ~$340m to liquidate
        erc20_mint(WETH, 3, address(benchmarkLiquidator), 10_000 ether);
        erc20_mint(USDC, 9, address(rebalancer),          type(uint256).max);

        assertEq(weth.balanceOf(address(liquidator)),        10_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        /******************************/
        /*** Piecewise Liquidations ***/
        /******************************/

        while(weth.balanceOf(address(liquidator)) > 0) {
            uint256 swapAmount = weth.balanceOf(address(liquidator)) > 450 ether ? 450 ether : weth.balanceOf(address(liquidator));  // Stay within 2% slippage

            sushiswapStrategy.flashBorrowLiquidation(address(liquidator), swapAmount, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

            rebalancer.swap(SUSHISWAP_ROUTER_V2, swapAmount, type(uint256).max, USDC, address(0), WETH);  // Perform fake arbitrage transaction to get price back up
        }

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        330_149_528_17844);  // Note that this is the exact same as the uniswap liquidation test, because the return amounts are the same.
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 328_752_316354);

        /*****************************/
        /*** Benchmark Liquidation ***/
        /*****************************/

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 10_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        sushiswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 10_000 ether, type(uint256).max, 0, WETH, address(0), USDC, address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 28_637_543_873315);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(uint256(28_637_543_873315) * 10 ** 18 / uint256(330_149_528_17844), 0.867411322115744850 ether);  // ~13.2% savings on $34m liquidation
    }

}

contract LiquidatorMultipleAMMTest is TestUtils {

    address public constant SUSHISWAP_ROUTER_V2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address public constant UNISWAP_ROUTER_V2   = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public constant USDC                = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_ORACLE         = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    address public constant WETH                = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant WETH_ORACLE         = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    IERC20 internal constant usdc = IERC20(USDC);
    IERC20 internal constant weth = IERC20(WETH);

    address internal constant fundsDestination  = address(5858);  // Address that collects expected funds from swaps
    address internal constant profitDestination = address(1122);  // Address that collects profits from swaps

    AuctioneerMock    internal auctioneer;
    Liquidator        internal liquidator;
    MapleGlobalsMock  internal globals;
    SushiswapStrategy internal sushiswapStrategy;
    UniswapV2Strategy internal uniswapV2Strategy;

    bool locked;  // Helper state variable to avoid infinite loops when using the modifier.

    modifier assertFailureWhenPaused() {
        if (!locked) {
            locked = true;

            globals.setProtocolPaused(true);

            ( bool success, ) = address(this).call(msg.data);
            assertTrue(!success || failed, "test should have failed when paused");

            globals.setProtocolPaused(false);
        }

        _;

        locked = false;
    }

    function setUp() external {
        globals = new MapleGlobalsMock();

        auctioneer        = new AuctioneerMock(address(globals), USDC);
        liquidator        = new Liquidator(address(this), WETH, USDC, address(auctioneer), fundsDestination, address(globals));
        sushiswapStrategy = new SushiswapStrategy();
        uniswapV2Strategy = new UniswapV2Strategy();

        auctioneer.__setValuesFor(WETH, 200, 2_000 * 10 ** 6);  // 1% slippage allowed from market price

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    // TODO: Update this test suite once UniswapV3 is implemented
    function test_liquidator_multipleStrategies() public assertFailureWhenPaused {
        erc20_mint(WETH, 3, address(liquidator), 1_400 ether);

        assertEq(weth.balanceOf(address(liquidator)),        1_400 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);

        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        // Try liquidating amounts that are above slippage requirements (determined with while loop)
        try sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 995 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination) { fail(); } catch {}
        try uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 484 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination) { fail(); } catch {}

        /**********************************/
        /*** Multi-Strategy Liquidation ***/
        /**********************************/

        uint256 returnAmount = liquidator.getExpectedAmount(1_400 ether);
        assertEq(returnAmount, 4_622_093_394499);  // $4.62m

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);
        uniswapV2Strategy.flashBorrowLiquidation(address(liquidator), 450 ether, type(uint256).max, 0, WETH, address(0), USDC, profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(weth.balanceOf(address(uniswapV2Strategy)), 0);

        assertWithinDiff(usdc.balanceOf(address(liquidator)), returnAmount, 1);

        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(uniswapV2Strategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 3_886_663971);
    }

}

contract LiquidatorOTCTest is TestUtils {

    address public constant fundsDestination = address(5959);
    address public constant USDC             = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_ORACLE      = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    address public constant WETH             = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant WETH_ORACLE      = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    IERC20 internal constant usdc = IERC20(USDC);
    IERC20 internal constant weth = IERC20(WETH);

    AuctioneerMock   internal auctioneer;
    Liquidator       internal liquidator;
    MapleGlobalsMock internal globals;

    bool locked;  // Helper state variable to avoid infinite loops when using the modifier.

    modifier assertFailureWhenPaused() {
        if (!locked) {
            locked = true;

            globals.setProtocolPaused(true);

            ( bool success, ) = address(this).call(msg.data);
            assertTrue(!success , "test should have failed when paused");

            globals.setProtocolPaused(false);
        }

        _;

        locked = false;
    }

    function setUp() external {
        globals = new MapleGlobalsMock();

        auctioneer = new AuctioneerMock(address(globals), USDC);
        liquidator = new Liquidator(address(this), WETH, USDC, address(auctioneer), fundsDestination, address(globals));

        auctioneer.__setValuesFor(WETH, 200, 2_000 * 10 ** 6);  // 2% slippage allowed from market price

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    function test_eoa_otc_liquidation() public assertFailureWhenPaused {
        erc20_mint(WETH, 3, address(liquidator), 1_400 ether);

        uint256 returnAmount1 = liquidator.getExpectedAmount(1_400 ether);

        assertEq(returnAmount1, 4_622_093_394499);

        erc20_mint(USDC, 9, address(this), returnAmount1);

        // Starting state
        assertEq(weth.balanceOf(address(liquidator)),       1_400 ether);
        assertEq(weth.balanceOf(address(this)),             0);
        assertEq(usdc.balanceOf(address(liquidator)),       0);
        assertEq(usdc.balanceOf(address(this)),             returnAmount1);

        usdc.approve(address(liquidator), returnAmount1 - 1);  // Approve for an amount less than the expected amount

        bytes memory arguments = new bytes(0);

        try liquidator.liquidatePortion(1_400 ether, type(uint256).max, arguments) { assertTrue(false, "Liquidation with less than approved amount"); } catch { }

        uint256 returnAmount2 = liquidator.getExpectedAmount(1_400 ether + 1);  // Return amount for over-liquidation

        assertEq(returnAmount2, returnAmount1);  // Small enough difference that return amounts are equal

        usdc.approve(address(liquidator), returnAmount1);  // Approve for the correct amount

        try liquidator.liquidatePortion(1_400 ether + 1, type(uint256).max, arguments) { assertTrue(false, "Liquidation for more than balance of liquidator"); } catch { }

        try liquidator.liquidatePortion(1_400 ether, returnAmount2 - 1, arguments) { assertTrue(false, "Liquidation for less than returnAmount"); } catch { }

        liquidator.liquidatePortion(1_400 ether, type(uint256).max, arguments);  // Successful when called with correct balance and approval

        // Ending state
        assertEq(weth.balanceOf(address(liquidator)),       0);
        assertEq(weth.balanceOf(address(this)),             1_400 ether);
        assertEq(usdc.balanceOf(address(liquidator)),       returnAmount1);
        assertEq(usdc.balanceOf(address(this)),             0);
    }

}

contract ReentrantLiquidatorTest is TestUtils {

    address public constant fundsDestination = address(5959);
    address public constant USDC             = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDC_ORACLE      = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    address public constant WETH             = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant WETH_ORACLE      = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    IERC20 internal constant usdc = IERC20(USDC);
    IERC20 internal constant weth = IERC20(WETH);

    AuctioneerMock      internal auctioneer;
    Liquidator          internal liquidator;
    MapleGlobalsMock    internal globals;
    ReentrantLiquidator internal reentrantStrategy;

    function setUp() external {
        globals = new MapleGlobalsMock();

        auctioneer = new AuctioneerMock(address(globals), USDC);
        liquidator = new Liquidator(address(this), WETH, USDC, address(auctioneer), fundsDestination, address(globals));

        auctioneer.__setValuesFor(WETH, 200, 2_000 * 10 ** 6);  // 2% slippage allowed from market price

        reentrantStrategy = new ReentrantLiquidator();

        globals.setPriceOracle(WETH, WETH_ORACLE);
        globals.setPriceOracle(USDC, USDC_ORACLE);
    }

    function test_liquidator_reentrantStrategy() public {
        erc20_mint(WETH, 3, address(liquidator), 1_400 ether);

        try reentrantStrategy.flashBorrowLiquidation(address(liquidator), 1_400 ether) { assertTrue(false, "Liquidation with less than approved amount"); } catch { }
    }

}
