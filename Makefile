## -----------------------------------------------------------------------------
## Common

.PHONY: clean
clean: ## Remove build artifacts
	@forge clean

.PHONY: build
build: ## Build project
	@forge build

.PHONY: update
update: ## Update dependencies
	@forge update

.PHONY: test
test: ## Run whole testsuite
	@forge test -vvv

## -----------------------------------------------------------------------------
## Individual Component Tests

.PHONY: testOracle
testOracle: ## Run Oracle tests
	@forge test -vvv --match-contract "Oracle"

.PHONY: testTreasury
testTreasury: ## Run Treasury tests
	@forge test -vvv --match-contract "Treasury"

.PHONY: testKOL
testKOL: ## Run KOL Token tests
	@forge test -vvv --match-contract "KOL"

.PHONY: testReserve
testReserve: ## Run Reserve tests
	@forge test -vvv --match-contract "Reserve"

.PHONY: testDiscountZapper
testDiscountZapper: ## Run Discount Zapper tests
	@forge test -vvv --match-contract "DiscountZapper"

.PHONY: testGeoNFT
testGeoNFT: ## Run GeoNFT tests
	@forge test -vvv --match-contract "GeoNFT"

## -----------------------------------------------------------------------------
## Static Analyzers

.PHONY: slither
slither: ## Run slither analyzer against project (requires solc-select)
	@solc-select install 0.8.10
	@solc-select use 0.8.10
	@slither src

# Something like this:
# @docker run -v $(pwd):/tmp mythril/myth analyze /tmp/<PATH TO CONTRACT>
.PHONY: mythril
mythril: ## Run mythril analyzer against project (requires docker)
	@echo "NOT YET IMPLEMENTED"

.PHONY: c4udit
c4udit: ## Run c4udit analyzer against project
	@c4udit src/

## -----------------------------------------------------------------------------
## Gas Snapshots and Reports

.PHONY: gas-report
gas-report: ## Run tests with gas reports
	@forge test --gas-report

.PHONY: gas-snapshots
gas-snapshots: ## Create test gas snapshots
	@forge snapshot

## -----------------------------------------------------------------------------
## Help Command

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
