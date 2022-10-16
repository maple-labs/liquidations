# Liquidations

![Foundry CI](https://github.com/maple-labs/liquidations/actions/workflows/push-to-main.yml/badge.svg)[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

## Overview

This repository holds the `Liquidator` contract. Whenever a borrower is no longer able to meet their obligations and a loan goes into default, the liquidation process can be triggered by the pool delegate which issued the loan. The goal of this process is to recover as much liquidity as possible from any assets that are still recoverable and minimize the losses suffered by the pool.

For more information about the `Liquidator` contract in the context of the Maple V2 protocol, please refer to the Liquidations section of the protocol [wiki](https://github.com/maple-labs/maple-core-v2/wiki/Liquidations).

## Dependencies/Inheritance

Contracts in this repo inherit and import code from:
- [`maple-labs/erc20`](https://github.com/maple-labs/erc20)
- [`maple-labs/erc20-helper`](https://github.com/maple-labs/erc20-helper)
- [`maple-labs/maple-proxy-factory`](https://github.com/maple-labs/maple-proxy-factory)

Contracts inherit and import code in the following ways:
- `Liquidator` uses `ERC20Helper` for token interactions.
- `Liquidator` inherits `MapleProxiedInternals` for proxy logic.
- `LiquidatorFactory` inherits `MapleProxyFactory` for proxy deployment and management.

Versions of dependencies can be checked with `git submodule status`.

## Setup

This project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation instructions [here](https://github.com/foundry-rs/foundry#installation).

```sh
git clone git@github.com:maple-labs/liquidations.git
cd liquidations
forge install
```

## Running Tests

- To run all tests: `./test.sh`
- To run specific unit tests: `./test.sh -t <test_name>`

## About Maple

[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

For all technical documentation related to the Maple V2 protocol, please refer to the GitHub [wiki](https://github.com/maple-labs/maple-core-v2/wiki).

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/116272804-33e78d00-a74f-11eb-97ab-77b7e13dc663.png" height="100" />
</p>
