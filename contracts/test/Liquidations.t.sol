// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }    from "../../modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { IOracle } from "../interfaces/Interfaces.sol";

import { Liquidations } from "../Liquidations.sol";

contract MapleGlobalsLike {

    mapping (address => address) public oracleFor;

    function maxSwapSlippage() external view returns(uint256) {
        return 1000;
    }

    function getLatestPrice(address asset) external view returns (uint256) {
        (uint80 roundID, int256 price,,uint256 timeStamp, uint80 answeredInRound) = IOracle(oracleFor[asset]).latestRoundData();
        return uint256(price);
    }

    function setPriceOracle(address asset, address oracle) external {
        oracleFor[asset] = oracle;
        emit OracleSet(asset, oracle);
    }

}

contract Loan {

    uint256 public collateral;

    constructor(uint256 collateral_) {
        collateral = collateral_;
    }

    function approveCollateral(address spender_, address collateralAsset_) external {
        IERC20(collateralAsset_).approve(spender_, collateral);
    }
    
}

contract LiquidationsUniswapTest is TestUtils {

    address public constant WETH              = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;
    address public constant USDC              = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;
    address public constant UNISWAP_ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant SUSHISWAP_ROUTER  = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address public constant WETH_ORACLE       = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDC_ORACLE       = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    MapleGlobalsLike mapleGlobals;
    Liquidations     liquidations;

    function setUp() external {
        mapleGlobals = new MapleGlobalsLike();
        liquidations = new Liquidations();

        mapleGlobals.setPriceOracle(WETH, WETH_ORACLE);
        mapleGlobals.setPriceOracle(USDC, USDC_ORACLE);
        liquidations.initialize(address(mapleGlobals));

        // Add market place & pair.
        liquidations.addMarketPlace(bytes32("Uniswap-v2"), UNISWAP_ROUTER_V2);
        liquidations.addMarketPlace(bytes32("Sushiswap"),  SUSHISWAP_ROUTER);

        liquidations.addMarketPair(bytes32("Uniswap-v2"), WETH, USDC, address(0));
        liquidations.addMarketPair(bytes32("Sushiswap"),  WETH, USDC, address(0));
    }

    function _mintCollateral(address to_, uint256 amount_) internal {

    } 

    function test_triggerDefault_withUniswap() external {
        // Create a loan
        Loan loan = new Loan(100 ether);

    }

}