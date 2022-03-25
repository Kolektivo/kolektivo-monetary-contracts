#!/bin/bash
#
# Deployment script for the Oracle.sol contract.
# MUST be called from the repo's root directory!
#
# Deployment is done through a `foundry create` call.

## Foundry Variables.
# The keystore file.
KEYSTORE=
# The RPC endpoint.
RPC_URL=
# The chain, e.g. mainnet, kovan...
CHAIN=

## Oracle's constructor arguments.
ARG1_ReportExpirationTime=7200      # 120 minutes
ARG2_ReportDelay=1800               # 30 minutes
ARG3_MinimumProviders=1

# The deploy command.
forge create                         \
    ./src/Oracle.sol:Oracle          \
    --chain $CHAIN                   \
    --rpc-url $RPC_URL               \
    --keystore $KEYSTORE             \
    --constructor-args               \
        $ARG1_ReportExpirationTime   \
        $ARG2_ReportDelay            \
        $ARG3_MinimumProviders
