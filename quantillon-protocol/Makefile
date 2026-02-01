# Quantillon Protocol - Development Makefile
# Integrates Foundry commands with Slither security analysis

.PHONY: help build test coverage slither clean validate-natspec docs gas-analysis analyze-warnings analyze-contract-sizes deploy-localhost deploy-base-sepolia deploy-base setup-env encrypt-env benchmark-gas

# Configuration variables
RESULTS_DIR ?= scripts/results
BUILD_OUTPUT := $(RESULTS_DIR)/build-output.log

# Default target
help:
	@echo "🔧 Quantillon Protocol Development Commands:"
	@echo ""
	@echo "🔐 Environment Management:"
	@echo "  make setup-env     - Set up environment from template"
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
	@echo "  make benchmark-gas - Run gas benchmarking for specific functions"
	@echo ""
	@echo "⚠️  Warning Analysis:"
	@echo "  make analyze-warnings - Analyze and isolate build warnings"
	@echo ""
	@echo "📏 Contract Size Analysis:"
	@echo "  make analyze-contract-sizes - Analyze contract sizes against EIP-170 limit"
	@echo ""
	@echo "📝 Documentation:"
	@echo "  make docs            - Generate HTML documentation"
	@echo "  make validate-natspec - Validate NatSpec documentation coverage"
	@echo ""
	@echo "🚀 Development:"
	@echo "  make all        - Build, test, and analyze security"
	@echo "  make ci         - Run CI/CD pipeline checks"
	@echo ""
	@echo "🌐 Deployment:"
	@echo "  make deploy-localhost     - Deploy to localhost with mock contracts"
	@echo "  make deploy-base-sepolia  - Deploy to Base Sepolia testnet with verification"
	@echo "  make deploy-base          - Deploy to Base mainnet with production settings"
	@echo "  make deploy-dry-run       - Test deployment without broadcasting"
	@echo ""
	@echo "🛡️  Secure Deployment (with pre-deployment checks):"
	@echo "  make deploy-secure-localhost    - Deploy to localhost with security checks"
	@echo "  make deploy-secure-base-sepolia - Deploy to Base Sepolia with security checks"
	@echo "  make deploy-secure-base         - Deploy to Base mainnet with security checks"
	@echo ""
	@echo "📝 Note: All deployments use standard environment variables"

# Environment setup (uses .env.localhost if .env.example is not present)
setup-env:
	@echo "🔐 Setting up environment from template..."
	@if [ ! -f .env ]; then \
		if [ -f .env.example ]; then \
			cp .env.example .env; \
		else \
			cp .env.localhost .env 2>/dev/null || true; \
		fi; \
		if [ -f .env ]; then \
			echo "✅ Created .env from template"; \
			echo "📝 Please edit .env with your actual values"; \
		else \
			echo "⚠️  No template found. Copy .env.localhost (or .env.base-sepolia) to .env"; \
		fi; \
	else \
		echo "⚠️  .env already exists, skipping template copy"; \
	fi


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
	FOUNDRY_PROFILE=coverage forge coverage --report lcov --ir-minimum
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

# Run gas benchmarking
benchmark-gas:
	@echo "⛽ Running gas benchmarking..."
	@cd "$(CURDIR)" && ./scripts/benchmark-gas.sh
	@echo "⛽ Gas benchmarking complete!"

# Analyze build warnings
analyze-warnings:
	@echo "⚠️  Analyzing build warnings..."
	@cd "$(CURDIR)" && ./scripts/analyze-warnings.sh
	@echo "⚠️  Warning analysis complete!"

# Analyze contract sizes against EIP-170 limit
analyze-contract-sizes:
	@echo "📏 Analyzing contract sizes against EIP-170 limit..."
	@cd "$(CURDIR)" && ./scripts/analyze-contract-sizes.sh
	@echo "📏 Contract size analysis complete!"

# Run all checks
all: build test coverage slither docs gas-analysis analyze-warnings analyze-contract-sizes
	@echo "🎯 All checks completed successfully!"

# Install dependencies
install:
	@echo "📥 Installing dependencies..."
	forge install
	@echo "📦 Installing Slither dependencies..."
	python3 -m venv venv
	./venv/bin/pip install -r requirements.txt
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

# CI/CD pipeline command (scripts encrypted via git-crypt, only build/test available in public CI)
ci: build test
	@echo "🚀 CI/CD pipeline completed!"

# Deployment commands using the unified deploy.sh script

# Deploy to localhost
deploy-localhost:
	@echo "🌐 Deploying to localhost with mock contracts..."
	@./scripts/deployment/deploy.sh localhost --with-mocks
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Deploy to Base Sepolia
deploy-base-sepolia:
	@echo "🌐 Deploying to Base Sepolia with verification..."
	@./scripts/deployment/deploy.sh base-sepolia --verify
	@echo "📋 Copying ABIs to frontend..."
	@./scripts/deployment/copy-abis.sh
	@echo "📍 Updating frontend addresses..."
	@./scripts/deployment/update-frontend-addresses.sh

# Deploy to Base mainnet
deploy-base:
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

# Security check before deployment
deploy-check:
	@echo "🔍 Running security checks before deployment..."
	@make slither
	@make validate-natspec
	@echo "✅ Security checks passed"

# Secure deployment targets (with pre-deployment security checks)
deploy-secure-localhost: deploy-check deploy-localhost
	@echo "🛡️  Secure localhost deployment completed"

deploy-secure-base-sepolia: deploy-check deploy-base-sepolia
	@echo "🛡️  Secure Base Sepolia deployment completed"

deploy-secure-base: deploy-check deploy-base
	@echo "🛡️  Secure Base mainnet deployment completed"
