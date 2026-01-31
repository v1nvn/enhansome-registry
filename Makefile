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
.PHONY: help lint lint-fix clean

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

clean: ## Remove built binaries
	@echo "🧹 Cleaning up binaries..."
	@rm -rf ./bin
