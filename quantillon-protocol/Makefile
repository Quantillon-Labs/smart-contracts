# Quantillon Protocol - Development Makefile
# Integrates Foundry commands with Slither security analysis

.PHONY: help build test coverage slither clean validate-natspec docs gas-analysis analyze-warnings

# Default target
help:
	@echo "🔧 Quantillon Protocol Development Commands:"
	@echo ""
	@echo "📦 Build & Compile:"
	@echo "  make build      - Compile all contracts"
	@echo "  make clean      - Clean build artifacts"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  make test       - Run all tests"
	@echo "  make coverage   - Generate test coverage report"
	@echo ""
	@echo "🔍 Security:"
	@echo "  make slither    - Run Slither security analysis"
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

# Build contracts
build:
	@echo "🔨 Building contracts..."
	forge build

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	forge clean

# Run tests
test:
	@echo "🧪 Running tests..."
	forge test

# Generate coverage report
coverage:
	@echo "📊 Generating coverage report..."
	forge coverage --report lcov

# Run Slither security analysis
slither:
	@echo "🔍 Running Slither security analysis..."
	@cd "$(CURDIR)" && ./scripts/run-slither.sh



# Run comprehensive security checks
security: build slither
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
