# Quantillon Protocol - Development Makefile
# Integrates Foundry commands with Slither security analysis

.PHONY: help build test coverage slither clean

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

# Run all checks
all: build test coverage slither
	@echo "🎯 All checks completed successfully!"

# Install dependencies
install:
	@echo "📥 Installing dependencies..."
	forge install
	@echo "📦 Installing Slither dependencies..."
	python3 -m venv venv
	./venv/bin/pip install -r requirements.txt

# CI/CD pipeline command
ci: build test slither
	@echo "🚀 CI/CD pipeline completed!"
