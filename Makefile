# ==============================================================================
# Tools and Binaries
# ==============================================================================

# Go
GO               := go
GOLANGCI_LINT    := golangci-lint

# ==============================================================================
# Tool Checks
# ==============================================================================

# Use this for loop and 'command -v' to check for the existence of each tool.
# This makes the Makefile more robust by warning the user about missing dependencies.
REQUIRED_TOOLS := $(GO) $(GOLANGCI_LINT)
$(foreach tool,$(REQUIRED_TOOLS),$(if $(shell command -v $(tool) 2>/dev/null),,$(warning "Warning: '$(tool)' is not installed or not in your PATH. Some targets may fail.")))

# ==============================================================================
# Variables
# ==============================================================================

# Define Go packages to be linted, tested, etc.
GO_PACKAGES := ./...

# ==============================================================================
# Phony Targets
# ==============================================================================

# Explicitly list all phony targets. This helps prevent conflicts with filenames
# and clearly documents the available commands.
.PHONY: help lint lint-fix test test-coverage test-unit test-concurrency \
	build run clean

.DEFAULT_GOAL := help

# ==============================================================================
# Main Targets
# ==============================================================================

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*?##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

lint: ## Run golangci-lint on the codebase
	@$(GOLANGCI_LINT) run -v --timeout=5m $(GO_PACKAGES)

lint-fix: ## Run golangci-lint and auto-fix issues
	@$(GOLANGCI_LINT) run --fix -v --timeout=5m $(GO_PACKAGES)

# --- Build and Run Targets ---

build: ## Build the auto-discover binary
	@echo "🔨 Building auto-discover..."
	@$(GO) build -o ./bin/auto-discover ./cmd/auto-discover
	@echo "✅ Build complete: ./bin/auto-discover"

run: build ## Build and run the auto-discover tool
	@./bin/auto-discover -allowlist ./allowlist.txt -denylist ./denylist.txt

clean: ## Remove built binaries
	@echo "🧹 Cleaning up binaries..."
	@rm -rf ./bin

# --- Test Targets ---

test: ## Run all tests
	@echo "🧪 Running all tests..."
	@$(GO) test -v -race -timeout 30s ./...

test-unit: ## Run unit tests only
	@echo "🧪 Running unit tests..."
	@$(GO) test -v -race -timeout 30s -run "TestUnit" ./...

test-concurrency: ## Run concurrency tests only
	@echo "🧪 Running concurrency tests..."
	@$(GO) test -v -race -timeout 30s -run "TestConcurrency" ./...

test-coverage: ## Run tests with coverage report
	@echo "🧪 Running tests with coverage..."
	@$(GO) test -coverprofile=coverage.out -covermode=atomic ./...
	@$(GO) tool cover -func=coverage.out
	@echo ""
	@echo "📊 To view HTML coverage report, run:"
	@echo "   go tool cover -html=coverage.out"
