# Liquidations

![Foundry CI](https://github.com/maple-labs/liquidations/actions/workflows/forge.yml/badge.svg)
[![GitBook - Documentation](https://img.shields.io/badge/GitBook-Documentation-orange?logo=gitbook&logoColor=white)](https://maplefinance.gitbook.io/maple/maple-for-developers/protocol-overview)
[![Foundry][foundry-badge]][foundry]
[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](https://github.com/maple-labs/liquidations/blob/main/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository holds the `Liquidator` contract. Whenever a borrower is no longer able to meet their obligations and a loan goes into default, the liquidation process can be triggered by the pool delegate which issued the loan. The goal of this process is to recover as much liquidity as possible from any assets that are still recoverable and minimize the losses suffered by the pool.

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

- Set the enviroment variable `ETH_RPC_URL` to mainnet url
- To run all tests: `forge test`
- To run specific tests: `forge test --match <test_name>`

`./scripts/test.sh` is used to enable Foundry profile usage with the `-p` flag. Profiles are used to specify the number of fuzz runs.

## Audit Reports

| Auditor | Report Link |
|---|---|
| Trail of Bits - LoanV2 | [`2021-12-28 - Trail of Bits Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-core/files/7847684/Maple.Finance.-.Final.Report_v3.pdf) |
| Code 4rena - LoanV2    | [`2022-01-05 - C4 Report`](https://code4rena.com/reports/2021-12-maple/) |
| Trail of Bits - LoanV3 | [`2022-04-12 - Trail of Bits Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-core/files/8507237/Maple.Finance.-.Final.Report.-.Fixes.pdf) |
| Code 4rena - LoanV3    | [`2022-04-20 - C4 Report`](https://code4rena.com/reports/2022-03-maple/) |
| Trail of Bits | [`2022-08-24 - Trail of Bits Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10246688/Maple.Finance.v2.-.Final.Report.-.Fixed.-.2022.pdf) |
| Spearbit | [`2022-10-17 - Spearbit Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10223545/Maple.Finance.v2.-.Spearbit.pdf) |
| Three Sigma | [`2022-10-24 - Three Sigma Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10223541/three-sigma_maple-finance_code-audit_v1.1.1.pdf) |

## Bug Bounty

For all information related to the ongoing bug bounty for these contracts run by [Immunefi](https://immunefi.com/), please visit this [site](https://immunefi.com/bounty/maple/).

## About Maple

[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

---

<p align="center">
  <img src="https://github.com/maple-labs/maple-metadata/blob/796e313f3b2fd4960929910cd09a9716688a4410/assets/maplelogo.png" height="100" />
</p>
