# Quantillon Protocol - Development Makefile

.PHONY: help build test coverage slither mythril security clean validate-natspec \
        docs gas-analysis benchmark-gas analyze-warnings analyze-contract-sizes \
        setup-env check-env install all ci \
        deploy-localhost deploy-base-sepolia deploy-base deploy-dry-run \
        deploy-check deploy-secure-localhost deploy-secure-base-sepolia deploy-secure-base

# ─── Configuration ────────────────────────────────────────────────────────────

RESULTS_DIR ?= scripts/results
BUILD_OUTPUT := $(RESULTS_DIR)/build-output.log
DEPLOY       := ./scripts/deployment/deploy.sh
BASH         ?= bash

# ─── Help ─────────────────────────────────────────────────────────────────────

help:
	@echo "🔧 Quantillon Protocol Development Commands:"
	@echo ""
	@echo "🔐 Environment:"
	@echo "  make setup-env              - Set up .env from template"
	@echo ""
	@echo "📦 Build:"
	@echo "  make build                  - Compile all contracts"
	@echo "  make clean                  - Clean build artifacts and results"
	@echo "  RESULTS_DIR=path make build - Use custom output directory"
	@echo ""
	@echo "🧪 Test:"
	@echo "  make test                   - Run all tests"
	@echo "  make coverage               - Generate lcov coverage report"
	@echo ""
	@echo "🔍 Security:"
	@echo "  make slither                - Slither static analysis"
	@echo "  make mythril                - Mythril symbolic execution"
	@echo "  make security               - build + slither + mythril"
	@echo "  make validate-natspec       - NatSpec coverage check"
	@echo ""
	@echo "⛽ Gas & Size:"
	@echo "  make gas-analysis           - Gas optimization analysis"
	@echo "  make benchmark-gas          - Gas benchmarking"
	@echo "  make analyze-warnings       - Build warning analysis"
	@echo "  make analyze-contract-sizes - EIP-170 size check"
	@echo ""
	@echo "📚 Docs & Install:"
	@echo "  make docs                   - Generate HTML documentation"
	@echo "  make install                - Install Forge, Python and npm dependencies"
	@echo ""
	@echo "🚀 Pipelines:"
	@echo "  make ci                     - CI pipeline (build+test+lint+analysis)"
	@echo "  make all                    - Full local pipeline (ci+coverage+docs+mythril)"
	@echo ""
	@echo "🌐 Deployment:"
	@echo "  make deploy-localhost       - Localhost with mock contracts (requires Anvil: anvil --port 8545)"
	@echo "  make deploy-base-sepolia    - Base Sepolia testnet with verification"
	@echo "  make deploy-base            - Base mainnet with production settings"
	@echo "  make deploy-dry-run         - Dry run (no broadcast)"
	@echo ""
	@echo "🛡️  Secure Deployment (pre-deployment checks included):"
	@echo "  make deploy-secure-localhost"
	@echo "  make deploy-secure-base-sepolia"
	@echo "  make deploy-secure-base"

# ─── Environment ──────────────────────────────────────────────────────────────

check-env:
	@test -f .env || (echo "❌ Missing .env — run 'make setup-env' first" && exit 1)

setup-env:
	@if [ -f .env ]; then \
		echo "⚠️  .env already exists, skipping"; \
	elif [ -f .env.example ]; then \
		cp .env.example .env && echo "✅ Created .env from .env.example — edit with your values"; \
	elif [ -f .env.localhost ]; then \
		cp .env.localhost .env && echo "✅ Created .env from .env.localhost — edit with your values"; \
	else \
		echo "❌ No template found (.env.example or .env.localhost)" && exit 1; \
	fi

# ─── Build ────────────────────────────────────────────────────────────────────

build:
	@echo "🔨 Building contracts..."
	@mkdir -p $(RESULTS_DIR)
	@$(BASH) -lc 'set -o pipefail; forge build --build-info --skip */test/** */script/** --force 2>&1 | tee "$(BUILD_OUTPUT)"'

clean:
	@echo "🧹 Cleaning build artifacts and results..."
	forge clean
	@rm -rf $(RESULTS_DIR)

# ─── Test & Coverage ──────────────────────────────────────────────────────────

test:
	@echo "🧪 Running tests..."
	FOUNDRY_PROFILE=test forge test

coverage:
	@echo "📊 Generating coverage report..."
	@mkdir -p $(RESULTS_DIR)
	FOUNDRY_PROFILE=coverage forge coverage --report lcov --ir-minimum
	@mv lcov.info $(RESULTS_DIR)/lcov.info
	@echo "📊 Coverage report saved to $(RESULTS_DIR)/lcov.info"

# ─── Security ─────────────────────────────────────────────────────────────────

slither:
	@echo "🔍 Running Slither..."
	@$(BASH) ./scripts/run-slither.sh

mythril:
	@echo "🔍 Running Mythril..."
	@./scripts/run-mythril.sh

security: build slither mythril
	@echo "🛡️  Security analysis complete!"

# ─── Documentation & Validation ───────────────────────────────────────────────

docs:
	@echo "📚 Generating HTML documentation..."
	@./scripts/build-docs.sh

# Sentinel: re-runs npm install only when scripts/package.json changes
scripts/node_modules/.install-sentinel: scripts/package.json
	cd scripts && npm install --silent
	@touch $@

validate-natspec: scripts/node_modules/.install-sentinel
	@echo "📝 Validating NatSpec documentation..."
	@cd scripts && node validate-natspec.js

# ─── Analysis ─────────────────────────────────────────────────────────────────

gas-analysis:
	@echo "⛽ Running gas analysis..."
	@$(BASH) ./scripts/analyze-gas.sh

benchmark-gas:
	@echo "⛽ Running gas benchmarking..."
	@./scripts/benchmark-gas.sh

analyze-warnings:
	@echo "⚠️  Analyzing build warnings..."
	@$(BASH) ./scripts/analyze-warnings.sh

analyze-contract-sizes:
	@echo "📏 Analyzing contract sizes against EIP-170..."
	@$(BASH) ./scripts/analyze-contract-sizes.sh

# ─── Pipelines ────────────────────────────────────────────────────────────────

# CI: fast pipeline for automated environments (no mythril, no coverage — run as separate jobs)
ci: build test slither validate-natspec gas-analysis analyze-warnings analyze-contract-sizes
	@echo "🚀 CI pipeline completed!"

# all: full local pipeline, builds on ci and adds slow targets
all: ci coverage docs mythril
	@echo "🎯 Full pipeline completed!"

# ─── Install ──────────────────────────────────────────────────────────────────

install:
	@echo "📥 Installing dependencies..."
	forge install
	python3 -m venv venv
	./venv/bin/pip install -r requirements.txt
	npm install

# ─── Deployment ───────────────────────────────────────────────────────────────
# deploy.sh handles ABIs and frontend address updates in post-deployment.

deploy-localhost:
	@echo "🌐 Deploying to localhost..."
	@$(DEPLOY) localhost --with-mocks

deploy-base-sepolia: check-env
	@echo "🌐 Deploying to Base Sepolia..."
	@$(DEPLOY) base-sepolia --verify

deploy-base: check-env
	@echo "🌐 Deploying to Base mainnet..."
	@$(DEPLOY) base --verify --production

deploy-dry-run:
	@echo "🧪 Dry-run deployment (no broadcast)..."
	@$(DEPLOY) localhost --dry-run

deploy-check:
	@echo "🔍 Running pre-deployment security checks..."
	@$(MAKE) slither
	@$(MAKE) validate-natspec
	@echo "✅ Pre-deployment checks passed"

deploy-secure-localhost: deploy-check deploy-localhost
	@echo "🛡️  Secure localhost deployment completed"

deploy-secure-base-sepolia: deploy-check deploy-base-sepolia
	@echo "🛡️  Secure Base Sepolia deployment completed"

deploy-secure-base: deploy-check deploy-base
	@echo "🛡️  Secure Base mainnet deployment completed"
