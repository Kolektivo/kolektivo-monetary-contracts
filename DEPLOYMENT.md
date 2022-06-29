<img align="right" width="150" height="150" top="100" src="./assets/kolektivo.png">

# Deployment

The Kolektivo contracts are deployed using foundry's script capabilities.

Each contract has a corresponding `.s.sol` script file in the `scripts/` directory.

The deployment script reads it's deployment arguments from environment variables, deploys the contract, and initiates an owner switch.

## Instructions

Define the deployment arguments for the contract in the `.env` file.

Source the `.env` file with `source xxx.env`, e.g. `source dev.env`.

Run:
```
forge script scripts/Deploy<Contract>.s.sol \
    --rpc-url $RPC_URL                      \
    --sender $WALLET_DEPLOYER               \
    --private-key $WALLET_DEPLOYER_PK       \
    --broadcast                             \
    -vvvv
```

If successful, the deployed contract's address is shown in the logs:
```
== Logs ==
  Deployment of Treasury at address, 0x0165878a594ca255338adfa4d48449f69242eb8f
  Owner switch succesfully initiated to address, 0x70997970c51812dc3a010c7d01b50e0d17dc79c8
```
