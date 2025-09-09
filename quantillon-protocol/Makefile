# Quantillon Protocol - Development Makefile
# Integrates Foundry commands with Slither security analysis

.PHONY: help build test coverage slither clean validate-natspec docs gas-analysis analyze-warnings deploy-localhost deploy-sepolia deploy-base deploy-full deploy-verify deploy-uups

# Configuration variables
RESULTS_DIR ?= results
BUILD_OUTPUT := $(RESULTS_DIR)/build-output.log

# Default target
help:
	@echo "🔧 Quantillon Protocol Development Commands:"
	@echo ""
	@echo "📦 Build & Compile:"
	@echo "  make build      - Compile all contracts"
	@echo "  make clean      - Clean build artifacts"
	@echo "  RESULTS_DIR=custom make build - Use custom output directory"
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
	@echo "🌐 Deployment:"
	@echo "  make deploy-localhost - Deploy to localhost"
	@echo "  make deploy-multisig  - Deploy with multisig configuration"
	@echo "  make init-multisig    - Initialize multisig deployment"
	@echo "  make verify-multisig  - Verify multisig deployment"
	@echo "  make deploy-sepolia   - Deploy to Sepolia testnet"
	@echo "  make deploy-base      - Deploy to Base mainnet"
	@echo "  make deploy-full      - Full UUPS deployment with verification"
	@echo "  make deploy-uups      - Deploy UUPS proxies only (localhost)"
	@echo "  make deploy-verify    - Verify deployed contracts"

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

# Deployment targets
deploy-localhost:
	@echo "🌐 Deploying to localhost..."
	@echo "⚠️  Make sure Anvil is running on localhost:8545"
	@export BASESCAN_API_KEY=dummy && forge script scripts/deployment/DeployQuantillon.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "✅ Localhost deployment completed!"

deploy-multisig:
	@echo "🌐 Deploying to localhost with multisig configuration..."
	@echo "⚠️  Make sure Anvil is running on localhost:8545"
	@export BASESCAN_API_KEY=dummy && forge script scripts/deployment/DeployMultisig.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "✅ Multisig deployment completed!"

init-multisig:
	@echo "⚙️ Initializing multisig deployment..."
	@echo "⚠️  Make sure contracts are deployed first"
	@forge script scripts/deployment/InitializeMultisig.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "✅ Multisig initialization completed!"

verify-multisig:
	@echo "🔍 Verifying multisig deployment..."
	@forge script scripts/deployment/VerifyMultisig.s.sol --rpc-url http://localhost:8545
	@echo "✅ Multisig verification completed!"

deploy-sepolia:
	@echo "🌐 Deploying to Sepolia testnet..."
	@echo "⚠️  Make sure PRIVATE_KEY and network environment variables are set"
	@export NETWORK=sepolia && forge script scripts/deployment/DeployNetwork.s.sol --rpc-url $(SEPOLIA_RPC_URL) --broadcast --verify
	@echo "✅ Sepolia deployment completed!"

deploy-base:
	@echo "🌐 Deploying to Base mainnet..."
	@echo "⚠️  Make sure PRIVATE_KEY and network environment variables are set"
	@export NETWORK=base && forge script scripts/deployment/DeployNetwork.s.sol --rpc-url $(BASE_RPC_URL) --broadcast --verify
	@echo "✅ Base deployment completed!"

deploy-full:
	@echo "🌐 Full UUPS deployment with verification..."
	@export BASESCAN_API_KEY=dummy && forge script scripts/deployment/DeployUUPS.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "✅ UUPS deployment completed!"
	@echo "🔍 Verifying deployment..."
	@forge script scripts/deployment/VerifyDeployment.s.sol --rpc-url http://localhost:8545
	@echo "✅ Full deployment with verification completed!"

deploy-uups:
	@echo "🌐 Deploying UUPS proxies to localhost..."
	@echo "⚠️  Make sure Anvil is running on localhost:8545"
	@export BASESCAN_API_KEY=dummy && forge script scripts/deployment/DeployUUPS.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "✅ UUPS proxy deployment completed!"

deploy-verify:
	@echo "🔍 Verifying deployed contracts..."
	@forge script scripts/deployment/VerifyDeployment.s.sol --rpc-url http://localhost:8545
	@echo "✅ Verification completed!"
