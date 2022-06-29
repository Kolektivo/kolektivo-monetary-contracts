
# == Start anvil Node as background process ==
#anvil --silent &

# == Deploy Base Contracts ==

# - Reserve2 Token Oracle
forge script scripts/DeployOracle.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - Reserve2 Token
forge script scripts/DeployReserve2Token.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - GeoNFT
forge script scripts/DeployGeoNFT.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - Treasury
forge script scripts/DeployTreasury.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - Reserve2
forge script scripts/DeployReserve2.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast
