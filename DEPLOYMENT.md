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
|------------------------|--------------------------------------------|
| Treasury               | 0x7521197233BD9235D2E39ad8D3D77c2843b2E837 |
| Reserve                | 0x61f99350eb8a181693639dF40F0C25371844fc32 |
| Reserve Token          | 0x65F0B6a36B850a12B06E5492dF4e13659A996796 |
| Geo NFT                | 0xc7D7407684c121d92f50440fC50353aefF6617b8 |
| Oracle: Treasury Token | 0x526Ab68ce3BEd2913d2B7e37EcaEc0f4ab81Df91 |
| Oracle: Reserve Token  | 0xD37aAd04CEbe9675010d05d7D0B33b15f2ED2443 |

| Other Contracts          | Address                                    |
|--------------------------|--------------------------------------------|
| ERC20 Mock Token         | 0xD5A8842F698D6170661376880b5aE20C17fD1FC3 |
| Oracle: ERC20 Mock Token | 0x917443A163adC3BeBFCb5ffD3a9D8161bE503D79 |
| Oracle: GeoNFT 1         | 0x38Bac6587302e06Bd84dca779c5Cb25483177667 |
