// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IOracle {
    
    function latestRoundData()
     external
     view
     returns (
        uint80  roundId,
        int256  answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80  answeredInRound
    );

}

interface IUniswapRouterLike {

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function WETH() external pure returns (address);

}

interface IMapleGlobalsLike {

    function maxSwapSlippage() external view returns(uint256);

    function getLatestPrice() external view returns(uint256);

}