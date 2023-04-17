# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                       	Kolektivo Makefile
#
# WARNING: This file is part of the git repo. DO NOT INCLUDE SENSITIVE DATA!
#
# The Kolektivo smart contracts project uses this Makefile to execute common
# tasks.
#
# The Makefile supports a help command, i.e. `make help`.
#
# Expected enviroment variables are defined in the `dev.env` file.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# -----------------------------------------------------------------------------
# Common

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

.PHONY: fmt
fmt: ## Format code
	@forge fmt

.PHONY: fmt-check
fmt-check: ## Check whether code formatted correctly
	@forge fmt --check

# -----------------------------------------------------------------------------
# Individual Component Tests

.PHONY: testOracle
testOracle: ## Run Oracle tests
	@forge test -vvv --match-contract "Oracle"

.PHONY: testTreasury
testTreasury: ## Run Treasury tests
	@forge test -vvv --match-contract "Treasury"

.PHONY: testElasticToken
testElasticToken: ## Run Elastic Receipt Token tests
	@forge test -vvv --match-contract "ElasticReceiptToken"

.PHONY: testReserveToken
testReserveToken: ## Run ReserveToken tests
	@forge test -vvv --match-contract "ReserveToken"

.PHONY: testReserve
testReserve: ## Run Reserve tests
	@forge test -vvv --match-contract "Reserve"

.PHONY: testGeoNFT
testGeoNFT: ## Run GeoNFT tests
	@forge test -vvv --match-contract "GeoNFT"

# -----------------------------------------------------------------------------
# Static Analyzers

.PHONY: analyze-slither
analyze-slither: ## Run slither analyzer against project (requires solc-select)
	@solc-select install 0.8.10
	@solc-select use 0.8.10
	@slither src

# Something like this:
# @docker run -v $(pwd):/tmp mythril/myth analyze /tmp/<PATH TO CONTRACT>
.PHONY: analyze-mythril
analyze-mythril: ## Run mythril analyzer against project (requires docker)
	@echo "NOT YET IMPLEMENTED"

.PHONY: analyze-c4udit
analyze-c4udit: ## Run c4udit analyzer against project
	@c4udit src

# -----------------------------------------------------------------------------
# Reports

.PHONY: gas-report
gas-report: ## Print gas report and create gas snapshots file
	@forge snapshot
	@forge test --gas-report

.PHONY: cov-report
cov-report: ## Print coverage report and create lcov report file
	@forge coverage --report lcov
	@forge coverage

# -----------------------------------------------------------------------------
# Help Command 

.PHONY: help
help:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
