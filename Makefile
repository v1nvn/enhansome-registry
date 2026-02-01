.PHONY: help test test-parallel test-single shellcheck lint ci clean install

# Default target
.DEFAULT_GOAL := help

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Testing

test: ## Run all tests
	@echo "Running all tests..."
	@bashunit tests/

test-parallel: ## Run tests in parallel (faster)
	@echo "Running tests in parallel..."
	@bashunit --parallel tests/

test-single: ## Run a single test file (usage: make test-single FILE=entry_test.sh)
	@echo "Running single test: $(FILE)"
	@bashunit tests/$(FILE)

test-lib: ## Run only lib tests
	@echo "Running lib tests..."
	@bashunit tests/lib/

##@ Code Quality

shellcheck: ## Run shellcheck on all scripts
	@echo "Running shellcheck..."
	@find scripts -name "*.sh" -exec shellcheck -W 0 {} + 2>&1 | grep -v SC1091 || true
	@find tests -name "*.sh" -exec shellcheck -W 0 {} + 2>&1 | grep -v SC1091 || true

lint: shellcheck ## Run all linting checks

##@ CI/CD

ci: lint test ## Run CI checks locally (lint + test)
	@echo "✅ CI checks passed!"

##@ Installation

install: ## Install dependencies (bashunit, shellcheck)
	@echo "Installing dependencies..."
	@command -v bashunit >/dev/null 2>&1 || \
		(echo "Installing bashunit..." && curl -s https://bashunit.typeddevs.com/install.sh | bash)
	@command -v shellcheck >/dev/null 2>&1 || \
		(echo "Installing shellcheck..." && brew install shellcheck)
	@echo "✅ All dependencies installed"

check-deps: ## Check if all dependencies are installed
	@echo "Checking dependencies..."
	@command -v bashunit >/dev/null 2>&1 && echo "✅ bashunit installed" || echo "❌ bashunit not installed"
	@command -v shellcheck >/dev/null 2>&1 && echo "✅ shellcheck installed" || echo "❌ shellcheck not installed"
	@command -v jq >/dev/null 2>&1 && echo "✅ jq installed" || echo "❌ jq not installed"

##@ Cleanup

clean: ## Clean up test artifacts
	@echo "Cleaning up test artifacts..."
	@rm -rf temp-data data/*.json 2>/dev/null || true
	@echo "✅ Cleanup complete"

##@ Utilities

stats: ## Show test statistics
	@echo "Test Statistics:"
	@echo "----------------"
	@echo "Total test files: $$(find tests -name "*_test.sh" | wc -l | tr -d ' ')"
	@echo "Total test functions: $$(grep -h "^function test_" tests/*.sh tests/lib/*.sh 2>/dev/null | wc -l | tr -d ' ')"
	@echo "Lines of script code: $$(find scripts -name "*.sh" -exec cat {} \; | wc -l | tr -d ' ')"
	@echo "Lines of test code: $$(find tests -name "*_test.sh" -exec cat {} \; | wc -l | tr -d ' ')"
