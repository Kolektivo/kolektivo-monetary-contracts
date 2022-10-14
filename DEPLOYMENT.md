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

## Testnet: Celo

Note that we did not initiate any owner switch on the testnet.

Note that the alfajores Celo testnet does not implement EIP1559 and the
`--legacy` flag needs to be appended to the deploy commands.

  | Kolektivo Contracts    | Address                                    |
  | ---------------------- | ------------------------------------------ |
  | Treasury               | 0x8Ddb762Fd4D56bd0D839732cC0c4538BCB5339cA |
  | Reserve                | 0xcBf30E615B5C2781BAc526b60E956D021984a707 |
  | Reserve Token          | 0xAF7C40a13b8a4e3e2017a61E4C2A4eDAd290D8B5 |
  | Oracle: Treasury Token | 0x7fB0D1E0286E159Ee50d409E2C5D4B9C9D2Ab7eb |
  | Oracle: Reserve Token  | 0xc444590ba59E44EbeC1fEB0f5579B597aF4531dC |
   
  | Other Contracts        | Address                                    |
  | ---------------------- | ------------------------------------------ |
  | ERC20 Mock Token 1     | 0x237ad41C8909976e9354a4BF3c2B7ba9a80c5e53 |
  | ERC20 Mock Token 2     | 0xD1563f11Ed13439C153B869389dB8d700596C0fb |
  | ERC20 Mock Token 3     | 0x91A7F78e341da0821757511204995ca32cE37b2E |
  | Oracle: Mock Token 1   | 0x4ea87725447C6F2A42EEcE0C63BB73C8805Ba075 |
  | Oracle: Mock Token 2   | 0x83501f3405eD8c7F8D3326e7990D6E3A1BB91aBe |
  | Oracle: Mock Token 3   | 0x873FBEB182e5417f07f40d7166391f5A0E9edd70 |
  | GeoNFT 1               | 0xE61A6d2093e93193fDB51134427eF67D4Bd77E06 |
  | Oracle: GeoNFT 1 ID 1  | 0xe5464F3031a20Cac208c2f4740cB8d212AC2eae7 |
  | Oracle: GeoNFT 1 ID 2  | 0x067552918D0EB75899f65F300436ed03f272f48D |
