#!/usr/bin/env bash
set -e

while getopts t:r: flag
do
    case "${flag}" in
        t) test=${OPTARG};;
        r) runs=${OPTARG};;
    esac
done

runs=$([ -z "$runs" ] && echo "1" || echo "$runs")

[[ $SKIP_MAINNET_CHECK || "$ETH_RPC_URL" && "$(cast chain)" == "ethlive" ]] || { echo "Please set a mainnet ETH_RPC_URL"; exit 1; }

export DAPP_FORK_BLOCK=13353817
export DAPP_SOLC_VERSION=0.8.7
export DAPP_SRC="contracts"
export PROPTEST_CASES=$runs

if [ -z "$test" ]; then match="[contracts/test/*.t.sol]"; else match=$test; fi

forge test --match-test "$match" --rpc-url "$ETH_RPC_URL" 
