<h1 align=center><code>
Kolektivo Smart Contracts
</code></h1>

## Installation

To install with [**DappTools**](https://github.com/dapphub/dapptools):

```sh
dapp install byterocket/KTT-Reserve
```

To install with [**Foundry**](https://github.com/gakonst/foundry):

```sh
forge install byterocket/KTT-Reserve
```

## Usage

Common tasks are executed through a `Makefile`:

```
make help
> build                    Build project
> clean                    Remove build artifacts
> test                     Run whole testsuite
> testKOL                  Run KOL token tests
> testOracle               Run Oracle tests
> testReserve              Run Reserve tests
> testTreasury             Run Treasury tests
> update                   Update dependencies
```

# Dependencies

- [byterocket's solrocket](https://github.com/byterocket/solrocket)
- [merkleplant's ElasticReceiptToken](https://github.com/pmerkleplant/elastic-receipt-token)
- [Rari Capital's solmate](https://github.com/rari-capital/solmate)

## Safety

This is experimental software and is provided on an "as is" and
"as available" basis.

We do not give any warranties and will not be liable for any loss incurred
through any use of this codebase.
