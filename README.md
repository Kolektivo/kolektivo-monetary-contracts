<img align="right" width="150" height="150" top="100" src="./assets/kolektivo.png">

# Kolektivo Smart Contracts

> Enabling Local Impact Economies

## Installation

The Kolektivo smart contracts are developed using the [foundry toolchain](https://getfoundry.sh).

However, the project also use hardhat _tasks_ and, therefore, also depends on hardhat.

1. Clone the repository
2. `cd` into the repository
3. Run `forge install` to install contract dependencies
4. Run `yarn` to install hardhat dependencies
5. (_Optional_) Run `source dev.env` to setup environment variables

## Usage

Common tasks are executed through a `Makefile`.

The `Makefile` supports a help command, i.e. `make help`.

```
$ make help
> build                    Build project
> clean                    Remove build artifacts
> test                     Run whole testsuite
> update                   Update dependencies
> [...]
```

## Simulation

This project includes a framework to simulate the contracts on a local node.

To start the simulation, first follow each step described in _Installation_.

Afterwards, start an `anvil` node in a second terminal session.

To start the simulation, run `npx hardhat simulation`.

## Dependencies

- [byterocket's solrocket](https://github.com/byterocket/solrocket)
- [merkleplant's ElasticReceiptToken](https://github.com/pmerkleplant/elastic-receipt-token)
- [Rari Capital's solmate](https://github.com/rari-capital/solmate)

## Safety

This is experimental software and is provided on an "as is" and
"as available" basis.

We do not give any warranties and will not be liable for any loss incurred
through any use of this codebase.
