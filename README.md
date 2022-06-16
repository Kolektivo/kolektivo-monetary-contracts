<img align="right" width="150" height="150" top="100" src="./assets/kolektivo.png">

# Kolektivo Smart Contracts

> Enabling Local Impact Economies

## Installation

The Kolektivo smart contracts are developed using the [foundry toolchain](https://getfoundry.sh).

For installation, run
```
forge install byterocket/kolektivo-contracts
```

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

## Dependencies

- [byterocket's solrocket](https://github.com/byterocket/solrocket)
- [merkleplant's ElasticReceiptToken](https://github.com/pmerkleplant/elastic-receipt-token)
- [Rari Capital's solmate](https://github.com/rari-capital/solmate)

## Safety

This is experimental software and is provided on an "as is" and
"as available" basis.

We do not give any warranties and will not be liable for any loss incurred
through any use of this codebase.
