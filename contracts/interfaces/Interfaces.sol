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

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint[] memory amounts);

}

interface IMapleGlobalsLike {

    function maxSwapSlippage() external view returns(uint256);

    function getLatestPrice(address asset) external view returns(uint256);

}
