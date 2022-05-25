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

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Run Debugger with:
# forge run ./src/test/<Contract>.t.sol --sig "<function>()" --debug
