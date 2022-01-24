# Liquidator

![Foundry CI](https://github.com/maple-labs/liquidations/actions/workflows/push-to-main.yml/badge.svg)[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

**DISCLAIMER: This code has NOT been externally audited and is actively being developed. Please do not use in production without taking the appropriate steps to ensure maximum security.**

Liquidator is a smart contract that performs the liquidation of ERC-20 assets using flashloans. To perform a liquidation, the following steps are performed:

1. Keeper calls `liquidatePortion`, specifying an amount of `collateralAsset` that they would like to liquidate.
2. The specified amount of `collateralAsset` is sent to the Keeper.
3. An arbitrary function call is made to `msg.sender`, allowing the opportunity for a strategy to be implemented to convert `collateralAsset` to `fundsAsset`
4. `getExpectedAmount` is called in the Auctioneer, a smart contract that returns the price of `collateralAsset` per unit `fundsAsset`.
5. This amount of `fundsAsset` is pulled from the Keeper using `transferFrom`. If this amount is not returned, the whole transaction will revert.

Two ready-to-use strategies are included in this repository, one to perform an AMM swap on UniswapV2, another to perform an AMM swap on Sushiswap.

An end to end example is outlined below:
1. 100 WBTC is put up for liquidation, with a market value of 60,000.00 USDC per WBTC ($6m of value total).
2. The Auctioneer is set to return a 2% discounted rate on the market value of WBTC, so it returns 58,800.00 USDC per WBTC.
3. One Keeper uses the UniswapV2 strategy to liquidate 40 WBTC
4. 40 WBTC is transferred to this Keeper, they swap 40 BTC on UniswapV2, incurring 1.5% slippage, getting 2,364,000 USDC
5. 40 WBTC at 58,800 USDC requires that 2,352,000 USDC be returned to the Liquidator.
6. Keeper is left the remaining funds, 12,000 USDC.
7. A second Keeper wants to buy the collateral outright, since they have enough USDC onhand.
8. The second Keeper simply calculates the amount required to buy the remaining 60 WBTC (3,528,000 USDC).
9. The second Keeper approves 3,528,000 USDC to the liquidator and calls `liquidatePortion` from their EOA.
10. This amount is pulled using `transferFrom`, and the 60 WBTC is sent to the second Keeper.

This style of liquidation allows for strategies to be implemented for users that are trying to liquidate collateral efficiently, and provides the opportunity for an OTC style liquidation to occur.

## Testing and Development
#### Setup
```sh
git clone git@github.com:maple-labs/liquidations.git
cd liquidations
dapp update
```
#### Running Tests
- To run all tests: `make test` (runs `./test.sh`)
- To run a specific test function: `./test.sh -t <test_name>` (e.g., `./test.sh -t test_setAllowedSlippage`)
- To run tests with a specified number of fuzz runs: `./test.sh -r <runs>` (e.g., `./test.sh -t test_setAllowedSlippage -r 10000`)

This project was built using [dapptools](https://github.com/dapphub/dapptools).

## Audit Reports
| Auditor | Report link |
|---|---|
| Trail of Bits                            | [ToB - Dec 28, 2021](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-core/files/7847684/Maple.Finance.-.Final.Report_v3.pdf) |
| Code 4rena                             | [C4 - Jan 5, 2022](https://code4rena.com/reports/2021-12-maple/) |

## About Maple
[Maple Finance](https://maple.finance) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

For all technical documentation related to the currently deployed Maple protocol, please refer to the maple-core GitHub [wiki](https://github.com/maple-labs/maple-core/wiki).

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/116272804-33e78d00-a74f-11eb-97ab-77b7e13dc663.png" height="100" />
</p>
