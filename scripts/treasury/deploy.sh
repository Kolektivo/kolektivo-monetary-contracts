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

## The Treasury has no constructor arguments.

# The deploy command.
forge create                    \
    ./src/Treasury.sol:Treasury \
    --chain $CHAIN              \
    --rpc-url $RPC_URL          \
    --keystore $KEYSTORE
