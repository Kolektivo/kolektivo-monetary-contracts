# Script to deploy a token with a price oracle

# - Token Oracle
forge script scripts/DeployOracle.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast

# - Token
forge script scripts/mocks/DeployERC20Mock.s.sol \
    --rpc-url $RPC_URL \
    --sender $WALLET_DEPLOYER \
    --private-key $WALLET_DEPLOYER_PK \
    --broadcast
