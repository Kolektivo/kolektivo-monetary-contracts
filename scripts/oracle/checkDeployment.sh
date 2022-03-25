#!/bin/bash
#
# Script to check invariants of Oracle deployment.
# MUST be called from the repo's root directory!

## Foundry Variables.
# The RPC endpoint.
RPC_URL=

## The Oracle address.
ORACLE=0x484B6B3477e2cf4ff95a8570A6A03AB5e09b6EaD

echo "ReportExpirationTime"
cast call $ORACLE "reportExpirationTime()" --rpc-url $RPC_URL

echo "reportDelay"
cast call $ORACLE "reportDelay()" --rpc-url $RPC_URL

echo "minimumProviders"
cast call $ORACLE "minimumProviders()" --rpc-url $RPC_URL

echo "isValid"
cast call $ORACLE "isValid()" --rpc-url $RPC_URL

echo "owner"
cast call $ORACLE "owner()" --rpc-url $RPC_URL

echo "pendingOwner"
cast call $ORACLE "pendingOwner()" --rpc-url $RPC_URL
