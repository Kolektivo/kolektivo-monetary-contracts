# Script to deploy Kolektivo Base Contracts

# - Reserve Token Oracle
forge script scripts/DeployOracle.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - Reserve Token
forge script scripts/DeployReserveToken.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - GeoNFT 1 Oracle
forge script scripts/DeployOracle.s.sol \
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

# - Treasury Token Oracle
forge script scripts/DeployOracle.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - Reserve
forge script scripts/DeployReserve.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast
