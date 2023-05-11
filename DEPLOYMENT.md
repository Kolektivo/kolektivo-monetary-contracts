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
  | Treasury               | 0x74b06277Cd1efaA9f6595D25AdB54b4530d15BF5 |
  | Reserve                | 0xdb2B19C8e3ce01E7f5101652B9dEb500D1298716 |
  | Reserve Token          | 0xf4cb43D02842c65101e5DA329ED01dFeC2280EdA |
  | Oracle: Treasury Token | 0x044bE97050A7225176391d47615CE0667DCBa134 |
  | Oracle: Reserve Token  | 0x86baecC60c5c1CCe2c73f2Ff42588E6EBce18707 |
   
  | Other Contracts        | Address                                    |
  | ---------------------- | ------------------------------------------ |
  | ERC20 Mock Token 1     | 0x4cB13ED364bd2c212B694921CdAca979DCA76054 |
  | ERC20 Mock Token 2     | 0x5bFE78b0d15eF0cdcA4077336e0bEbEc15CFb142 |
  | ERC20 Mock Token 3     | 0xd312bCeA257799a39e0C85d7EC45031612e4dd50 |
  | Oracle: Mock Token 1   | 0x377898651e03A9c1562F739a40bda70a18715cdD |
  | Oracle: Mock Token 2   | 0xBb6fB0e7510744c8234dFA78D5088fF9AD550A88 |
  | Oracle: Mock Token 3   | 0xe898a9e58105414eA4066C8b6a15F0D9F2f4A5dc |
  | GeoNFT 1               | 0x9fC5461A1e6CF567C7E19Befa7c0351C9C6CB719 |
  | Oracle: GeoNFT 1 ID 1  | 0xCf79C474994a7441E908C73Dd6cc3869dCfeD6cF |
  | Oracle: GeoNFT 1 ID 2  | 0x1011AdbFe0E41c610FF633DC6EfA6D67A2CfA978 | 
