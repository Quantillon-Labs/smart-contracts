# Quantillon Protocol - Development Makefile
# Integrates Foundry commands with Slither security analysis and dotenvx encryption

.PHONY: help build test coverage slither clean validate-natspec docs gas-analysis analyze-warnings deploy-localhost deploy-base-sepolia deploy-base setup-env encrypt-env

# Configuration variables
RESULTS_DIR ?= scripts/results
BUILD_OUTPUT := $(RESULTS_DIR)/build-output.log

# Default target
help:
	@echo "🔧 Quantillon Protocol Development Commands:"
	@echo ""
	@echo "🔐 Environment Management:"
	@echo "  make setup-env     - Set up environment from template"
	@echo "  make encrypt-env   - Encrypt environment variables with dotenvx"
	@echo "  make decrypt-test  - Test environment variable decryption"
	@echo ""
	@echo "📦 Build & Compile:"
	@echo "  make build      - Compile all contracts"
	@echo "  make clean      - Clean build artifacts"
	@echo "  RESULTS_DIR=custom make build - Use custom output directory (default: scripts/results)"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  make test       - Run all tests"
	@echo "  make coverage   - Generate test coverage report"
	@echo ""
	@echo "🔍 Security:"
	@echo "  make slither    - Run Slither security analysis"
	@echo "  make mythril    - Run Mythril symbolic execution analysis"
	@echo "  make security   - Run comprehensive security checks"
	@echo ""
	@echo "⛽ Gas Analysis:"
	@echo "  make gas-analysis - Run comprehensive gas optimization analysis"
	@echo ""
	@echo "⚠️  Warning Analysis:"
	@echo "  make analyze-warnings - Analyze and isolate build warnings"
	@echo ""
	@echo "📝 Documentation:"
	@echo "  make docs            - Generate HTML documentation"
	@echo "  make validate-natspec - Validate NatSpec documentation coverage"
	@echo ""
	@echo "🚀 Development:"
	@echo "  make all        - Build, test, and analyze security"
	@echo ""
	@echo "🌐 Deployment (Unified Script):"
	@echo "  make deploy-localhost     - Deploy to localhost with mock contracts"
	@echo "  make deploy-base-sepolia  - Deploy to Base Sepolia testnet with verification"
	@echo "  make deploy-base          - Deploy to Base mainnet with production settings"
	@echo "  make deploy-dry-run       - Test deployment without broadcasting"
	@echo ""
	@echo "🔧 Advanced Deployment:"
	@echo "  make deploy-localhost-mocks    - Deploy to localhost with mock contracts"
	@echo "  make deploy-base-sepolia-verify - Deploy to Base Sepolia with verification"
	@echo "  make deploy-base-production    - Deploy to Base mainnet with production settings"
	@echo ""
	@echo "📝 Note: All deployments use encrypted environment variables with dotenvx"

# Environment setup
setup-env:
	@echo "🔐 Setting up environment from template..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ Created .env from template"; \
		echo "📝 Please edit .env with your actual values"; \
	else \
		echo "⚠️  .env already exists, skipping template copy"; \
	fi

# Encrypt environment variables
encrypt-env:
	@echo "🔐 Encrypting environment variables with dotenvx..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Run 'make setup-env' first"; \
		exit 1; \
	fi
	@npx dotenvx encrypt .env
	@echo "✅ Environment variables encrypted successfully"
	@echo "🔑 Private key saved to .env.keys (NEVER commit this file)"

# Test environment decryption
decrypt-test:
	@echo "🔍 Testing environment variable decryption..."
	@if [ ! -f .env.keys ]; then \
		echo "❌ .env.keys file not found. Run 'make encrypt-env' first"; \
		exit 1; \
	fi
	@npx dotenvx run -- echo "✅ Environment decryption working"

# Build contracts
build:
	@echo "🔨 Building contracts..."
	@mkdir -p $(RESULTS_DIR)
	forge build --force 2>&1 | tee $(BUILD_OUTPUT)

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	forge clean
	@echo "🧹 Cleaning results directory..."
	@rm -rf $(RESULTS_DIR)

# Run tests
test:
	@echo "🧪 Running tests..."
	forge test

# Generate coverage report
coverage:
	@echo "📊 Generating coverage report..."
	FOUNDRY_PROFILE=coverage forge coverage --report lcov
	@echo "🧹 Cleaning up coverage file..."
	@rm -f lcov.info

# Run Slither security analysis
slither:
	@echo "🔍 Running Slither security analysis..."
	@cd "$(CURDIR)" && ./scripts/run-slither.sh

# Run Mythril symbolic execution analysis
mythril:
	@echo "🔍 Running Mythril symbolic execution analysis..."
	@cd "$(CURDIR)" && ./scripts/run-mythril.sh

# Run comprehensive security checks
security: build slither mythril
	@echo "🛡️  Security analysis complete!"

# Run comprehensive gas analysis
gas-analysis:
	@echo "⛽ Running comprehensive gas analysis..."
	@cd "$(CURDIR)" && ./scripts/analyze-gas.sh
	@echo "⛽ Gas analysis complete!"

# Analyze build warnings
analyze-warnings:
	@echo "⚠️  Analyzing build warnings..."
	@cd "$(CURDIR)" && ./scripts/analyze-warnings.sh
	@echo "⚠️  Warning analysis complete!"

# Run all checks
all: build test coverage slither docs gas-analysis analyze-warnings
	@echo "🎯 All checks completed successfully!"

# Install dependencies
install:
	@echo "📥 Installing dependencies..."
	forge install
	@echo "📦 Installing Slither dependencies..."
	python3 -m venv venv
	./venv/bin/pip install -r requirements.txt
	@echo "📦 Installing dotenvx..."
	npm install

# Generate HTML documentation
docs:
	@echo "📚 Generating HTML documentation..."
	@cd "$(CURDIR)" && ./scripts/build-docs.sh

# Validate NatSpec documentation
validate-natspec:
	@echo "📝 Validating NatSpec documentation..."
	@cd scripts && npm install --silent
	@cd scripts && node validate-natspec.js

# CI/CD pipeline command
ci: build test slither validate-natspec gas-analysis analyze-warnings
	@echo "🚀 CI/CD pipeline completed!"

# Unified deployment commands using the new deploy.sh script

# Deploy to localhost
deploy-localhost:
	@echo "🌐 Deploying to localhost with unified script..."
	@./scripts/deployment/deploy.sh localhost --with-mocks
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Deploy to localhost with mock contracts
deploy-localhost-mocks:
	@echo "🌐 Deploying to localhost with mock contracts..."
	@./scripts/deployment/deploy.sh localhost --with-mocks
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Deploy to Base Sepolia
deploy-base-sepolia:
	@echo "🌐 Deploying to Base Sepolia with unified script..."
	@./scripts/deployment/deploy.sh base-sepolia --verify
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Deploy to Base Sepolia with verification
deploy-base-sepolia-verify:
	@echo "🌐 Deploying to Base Sepolia with verification..."
	@./scripts/deployment/deploy.sh base-sepolia --verify
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Deploy to Base mainnet
deploy-base:
	@echo "🌐 Deploying to Base mainnet with unified script..."
	@./scripts/deployment/deploy.sh base --production --verify
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Deploy to Base mainnet with production settings
deploy-base-production:
	@echo "🌐 Deploying to Base mainnet with production settings..."
	@./scripts/deployment/deploy.sh base --production --verify
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Dry run deployment (test without broadcasting)
deploy-dry-run:
	@echo "🧪 Testing deployment with dry run..."
	@./scripts/deployment/deploy.sh localhost --dry-run

# Legacy compatibility targets (deprecated but still working)
deploy-localhost-with-mock-usdc: deploy-localhost-mocks
	@echo "⚠️  This target is deprecated. Use 'make deploy-localhost-mocks' instead"

# Security check before deployment
deploy-check:
	@echo "🔍 Running security checks before deployment..."
	@make slither
	@make validate-natspec
	@echo "✅ Security checks passed"

# Full deployment with security checks
deploy-secure-localhost: deploy-check deploy-localhost
	@echo "🛡️  Secure localhost deployment completed"

deploy-secure-base-sepolia: deploy-check deploy-base-sepolia
	@echo "🛡️  Secure Base Sepolia deployment completed"

deploy-secure-base: deploy-check deploy-base
	@echo "🛡️  Secure Base mainnet deployment completed"
