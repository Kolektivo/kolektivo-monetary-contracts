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
| Treasury               | 0x030Cd6F06FFf3728ac7bF50EF7b2a38DFD517237 |
| Reserve                | 0xBccd7dA2A8065C588caFD210c33FC08b00d36Df9 |
| Reserve Token          | 0x6f10D2FbcBEa5908bc0d4ed3656E61c29Db9c324 |
| Geo NFT                | 0x7E914eC3F65E1dc1B27258ffAE6B21Cc67330BA0 |
| Oracle: Treasury Token | 0xED282D1EAbd32C3740Ee82fa1A95bd885A69f3bB |
| Oracle: Reserve Token  | 0xA6B5122385c8aF4a42E9e9217301217B9cdDbC49 |

| Other Contracts            | Address                                    |
| -------------------------- | ------------------------------------------ |
| ERC20 Mock Token 1         | 0x434f234916Bbf0190BE3f058DeD9d8889953c4b4 |
| ERC20 Mock Token 2         | 0xd4482BAEa5c6426687a8F66de80bb857fE1942f1 |
| ERC20 Mock Token 3         | 0x290DB975a9Aa2cb6e34FC0A09794945B383d7cCE |
| Oracle: ERC20 Mock Token 1 | 0x2066a9c878c26FA29D4fd923031C3C40375d1c0D |
| Oracle: ERC20 Mock Token 2 | 0xce37a77D34f05325Ff1CC0744edb2845349307F7 |
| Oracle: ERC20 Mock Token 3 | 0x923b14F630beA5ED3D47338469c111D6d082B3E8 |
| Oracle: GeoNFT 1           | 0xFeF224e7fdFf2279AE42c33Fb47397A89503186b |
