#!/bin/bash
#
# Script to check invariants of Oracle deployment.
# MUST be called from the repo's root directory!

## Foundry Variables.
# The RPC endpoint.
RPC_URL=

## The Oracle address.
ORACLE=0x484B6B3477e2cf4ff95a8570A6A03AB5e09b6EaD

echo "Report Expiration Time"
cast call $ORACLE "reportExpirationTime()" --rpc-url $RPC_URL
echo "Report Delay"
cast call $ORACLE "reportDelay()" --rpc-url $RPC_URL
echo "Minimum Providers"
cast call $ORACLE "minimumProviders()" --rpc-url $RPC_URL
echo "Is Valid"
cast call $ORACLE "isValid()" --rpc-url $RPC_URL

echo "Owner"
cast call $ORACLE "owner()" --rpc-url $RPC_URL
echo "Pending Owner"
cast call $ORACLE "pendingOwner()" --rpc-url $RPC_URL
