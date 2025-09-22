#!/usr/bin/env bash

set -euo pipefail

# Locations
ROOT_DIR="/home/uld/GitHub"
CONTRACTS_DIR="$ROOT_DIR/smart-contracts/quantillon-protocol"
FRONTEND_DIR="$ROOT_DIR/quantillon-dapp"
BACKEND_DIR="$FRONTEND_DIR/backend"

# Logs
LOG_DIR="$ROOT_DIR/.localstack-logs"
mkdir -p "$LOG_DIR"
ANVIL_LOG="$LOG_DIR/anvil.log"
DEPLOY_LOG="$LOG_DIR/deploy.log"
BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"

# Processes/ports
ANVIL_PORT=8545
BACKEND_PORT=4000
FRONTEND_PORT=3001

function info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
function warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
function error() { echo -e "\033[1;31m[ERR ]\033[0m $*"; }

kill_by_name() {
  local name="$1"
  if pgrep -f "$name" >/dev/null 2>&1; then
    info "Killing processes matching: $name"
    pkill -f "$name" || true
    sleep 0.5
  fi
}

free_port() {
  local port="$1"
  if lsof -i ":$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
    local pids
    pids=$(lsof -i ":$port" -sTCP:LISTEN -t || true)
    if [[ -n "$pids" ]]; then
      info "Freeing port $port (pids: $pids)"
      kill $pids || true
      sleep 0.5
    fi
  fi
}

wait_for_http() {
  local url="$1"; local timeout="${2:-30}"; local name="${3:-service}"
  local start=$(date +%s)
  until curl -sSf "$url" >/dev/null 2>&1; do
    if (( $(date +%s) - start > timeout )); then
      error "Timeout waiting for $name at $url"
      return 1
    fi
    sleep 0.5
  done
  info "$name is up at $url"
}

wait_for_tcp() {
  local host="$1"; local port="$2"; local timeout="${3:-30}"; local name="${4:-service}"
  local start=$(date +%s)
  until (echo > /dev/tcp/$host/$port) >/dev/null 2>&1; do
    if (( $(date +%s) - start > timeout )); then
      error "Timeout waiting for $name on $host:$port"
      return 1
    fi
    sleep 0.5
  done
  info "$name is listening on $host:$port"
}

start_anvil() {
  info "Starting fresh Anvil on :$ANVIL_PORT"
  kill_by_name "anvil"
  free_port "$ANVIL_PORT"
  nohup anvil --host 0.0.0.0 --port "$ANVIL_PORT" --accounts 10 --balance 10000 > "$ANVIL_LOG" 2>&1 &
  sleep 0.5
  wait_for_tcp 127.0.0.1 "$ANVIL_PORT" 30 "anvil"
}

deploy_contracts() {
  info "Deploying contracts to localhost via unified deployment script with mock contracts"
  pushd "$CONTRACTS_DIR" >/dev/null
  
  # Check if environment is properly set up
  if [ ! -f ".env.keys" ]; then
    warn "No .env.keys file found. Checking if environment is encrypted..."
    if grep -q "DOTENV_PUBLIC_KEY" .env 2>/dev/null; then
      error "Environment is encrypted but .env.keys file is missing!"
      error "Please ensure you have the decryption key file."
      exit 1
    else
      warn "Environment is not encrypted. Consider running 'make encrypt-env' for security."
    fi
  fi
  
  # Use the new unified deployment script with mock contracts
  info "Using unified deployment script: ./scripts/deployment/deploy.sh localhost --with-mocks"
  ./scripts/deployment/deploy.sh localhost --with-mocks 2>&1 | tee "$DEPLOY_LOG"
  
  # Copy ABIs and update frontend addresses (no parameters needed for new script)
  info "Copying ABIs to frontend..."
  ./scripts/deployment/copy-abis.sh
  info "Updating frontend addresses..."
  ./scripts/deployment/update-frontend-addresses.sh
  
  popd >/dev/null
}

start_backend() {
  info "Starting backend on :$BACKEND_PORT"
  kill_by_name "node .*$BACKEND_DIR/index.js"
  free_port "$BACKEND_PORT"
  pushd "$BACKEND_DIR" >/dev/null
  nohup npm run start --silent > "$BACKEND_LOG" 2>&1 &
  popd >/dev/null
  wait_for_http "http://127.0.0.1:$BACKEND_PORT/api/test" 30 "backend"
}

start_frontend() {
  info "Starting frontend (Vite) on :$FRONTEND_PORT with encrypted environment"
  kill_by_name "vite"
  free_port "$FRONTEND_PORT"
  pushd "$FRONTEND_DIR" >/dev/null
  
  # Check if frontend environment is properly set up
  if [ ! -f ".env.keys" ]; then
    warn "No .env.keys file found in frontend. Checking if environment is encrypted..."
    if grep -q "DOTENV_PUBLIC_KEY" .env 2>/dev/null; then
      error "Frontend environment is encrypted but .env.keys file is missing!"
      error "Please ensure you have the decryption key file."
      exit 1
    else
      warn "Frontend environment is not encrypted. Consider running 'npx dotenvx encrypt .env' for security."
    fi
  fi
  
  # Use dotenvx for secure environment variable loading
  nohup npm run dev -- --host 0.0.0.0 --port "$FRONTEND_PORT" > "$FRONTEND_LOG" 2>&1 &
  popd >/dev/null
  # Vite dev server root responds with HTML; just check TCP
  wait_for_tcp 127.0.0.1 "$FRONTEND_PORT" 30 "frontend"
}

check_environment() {
  info "Checking environment setup..."
  
  # Check smart contracts environment
  pushd "$CONTRACTS_DIR" >/dev/null
  if [ ! -f ".env" ]; then
    error "No .env file found in smart contracts directory!"
    error "Please run 'make setup-env' in the smart contracts directory first."
    exit 1
  fi
  
  if [ ! -f ".env.keys" ] && ! grep -q "DOTENV_PUBLIC_KEY" .env 2>/dev/null; then
    warn "Smart contracts environment is not encrypted."
    warn "Consider running 'make encrypt-env' for security."
  fi
  popd >/dev/null
  
  # Check frontend environment
  pushd "$FRONTEND_DIR" >/dev/null
  if [ ! -f ".env" ]; then
    error "No .env file found in frontend directory!"
    error "Please copy .env.example to .env and configure it."
    exit 1
  fi
  
  if [ ! -f ".env.keys" ] && ! grep -q "DOTENV_PUBLIC_KEY" .env 2>/dev/null; then
    warn "Frontend environment is not encrypted."
    warn "Consider running 'npx dotenvx encrypt .env' for security."
  fi
  popd >/dev/null
}

main() {
  info "🚀 Starting Quantillon Protocol Local Stack"
  info "Logs: $LOG_DIR"
  
  # Check environment setup first
  check_environment
  
  # Start services
  start_anvil
  deploy_contracts
  start_backend
  start_frontend
  
  info "✅ All services started successfully!"
  echo ""
  echo "📊 Service Status:"
  echo "- Anvil (Blockchain):     http://127.0.0.1:$ANVIL_PORT"
  echo "- Backend (API):          http://127.0.0.1:$BACKEND_PORT"
  echo "- Frontend (dApp):        http://127.0.0.1:$FRONTEND_PORT"
  echo ""
  echo "📋 Log Files:"
  echo "- Anvil logs:     $ANVIL_LOG"
  echo "- Deploy logs:    $DEPLOY_LOG"
  echo "- Backend logs:   $BACKEND_LOG"
  echo "- Frontend logs:  $FRONTEND_LOG"
  echo ""
  echo "🔐 Security Notes:"
  echo "- Environment variables are encrypted with dotenvx"
  echo "- Private keys (.env.keys) are not committed to version control"
  echo "- All deployments use secure environment variable loading"
}

main "$@"
