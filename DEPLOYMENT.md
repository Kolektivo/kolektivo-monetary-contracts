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

# Deployments

## Testnet: alfajores (Celo)

Note that we did not initiate any owner switch on the testnet.

Note that the alfajores Celo testnet does not implement EIP1559 and the
`--legacy` flag needs to be appended to the deploy commands.

| Kolektivo Contracts    | Address                                    |
| ---------------------- | ------------------------------------------ |
| Treasury               | 0xEAc68B2e33fA3dbde9bABf3edF17ed3437f3D992 |
| Reserve                | 0x9f4995f6a797Dd932A5301f22cA88104e7e42366 |
| Reserve Token          | 0x799aC807A4163899c09086A6C69490f6AecD65Cb |
| Geo NFT                | 0x3d088f32d7d83FD7868620f76C80604106b74702 |
| Oracle: Treasury Token | 0x07aDaa5739fF6d730CB9D59991072b17a70D9813 |
| Oracle: Reserve Token  | 0x8684e1f9da7036adFF3D95BA54Db9Ef0F503f5D4 |

| Other Contracts            | Address                                    |
| -------------------------- | ------------------------------------------ |
| ERC20 Mock Token 1         | 0x8E7Af361418CDAb43333c6Bd0fA6906285C0E272 |
| ERC20 Mock Token 2         | 0x57f046C697B15D0933605F12152c5d96cB6f9cc5 |
| ERC20 Mock Token 3         | 0x32dB9295556D2B5193FD404253a4a3fD206B754b |
| Oracle: ERC20 Mock Token 1 | 0x8e44992e836A742Cdcde08346DB6ECEac86C5C41 |
| Oracle: ERC20 Mock Token 2 | 0x1A9617212f01846961256717781214F9956512Be |
| Oracle: ERC20 Mock Token 3 | 0xBbD9C2bB9901464ef92dbEf3E2DE98b744bA49D5 |
| Oracle: GeoNFT 1           | 0x4CF7C83253B850BC50dC641aB7D4136aE934f77f |
| Oracle: GeoNFT 2           | 0x5dfD0c7d607a08F07F3041a86338404442615127 |
