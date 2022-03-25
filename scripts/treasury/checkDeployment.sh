#!/bin/bash
#
# Script to check invariants of Oracle deployment.
# MUST be called from the repo's root directory!

## Foundry Variables.
# The RPC endpoint.
RPC_URL=

## The Treasury address.
TREASURY=0xfa62380AE042b39A0448ce8A8f503716d0B05A59

echo "Name"
cast call $TREASURY "name()" --rpc-url $RPC_URL
echo "Symbol"
cast call $TREASURY "symbol()" --rpc-url $RPC_URL
echo "Decimals"
cast call $TREASURY "decimals()" --rpc-url $RPC_URL
echo "Total Supply"
cast call $TREASURY "totalSupply()" --rpc-url $RPC_URL
echo "Total Valuation"
cast call $TREASURY "totalValuation()" --rpc-url $RPC_URL

echo "Owner"
cast call $TREASURY "owner()" --rpc-url $RPC_URL
echo "Pending Owner"
cast call $TREASURY "pendingOwner()" --rpc-url $RPC_URL
