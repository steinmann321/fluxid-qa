#!/usr/bin/env bash
set -euo pipefail

# AI-First Code Quality Enforcement System
# Enterprise-grade QA for AI-generated Django + React + Playwright codebases
# Enforces strict quality gates to ensure AI-generated code meets professional production standards

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory (where templates are located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/.hook-templates"

# Target directory (provided as argument)
TARGET_DIR=""

# Project folders (to be detected)
BACKEND_DIR=""
FRONTEND_DIR=""
E2E_DIR=""

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# ==============================================================================
# PHASE 1: DETECTION
# ==============================================================================

detect_project_folders() {
    log_info "Detecting project structure in: $TARGET_DIR"

    cd "$TARGET_DIR"

    # Check for backend (Django)
    if [[ -d "backend" ]] && [[ -f "backend/manage.py" ]]; then
        BACKEND_DIR="backend"
        log_success "Found Django backend in: backend/"
    else
        # Try to find Django project in other locations
        local django_dir=$(find . -maxdepth 2 -name "manage.py" -exec dirname {} \; 2>/dev/null | head -1)
        if [[ -n "$django_dir" ]]; then
            BACKEND_DIR="${django_dir#./}"
            log_success "Found Django backend in: $BACKEND_DIR/"
        else
            log_warning "No Django backend found (skipping backend setup)"
        fi
    fi

    # Check for frontend (React)
    if [[ -d "frontend" ]] && [[ -f "frontend/package.json" ]]; then
        if grep -q "react" "frontend/package.json" 2>/dev/null; then
            FRONTEND_DIR="frontend"
            log_success "Found React frontend in: frontend/"
        fi
    else
        # Try to find React project in other locations
        local react_dir=$(find . -maxdepth 2 -name "package.json" -exec sh -c 'grep -q "react" "$1" && dirname "$1"' _ {} \; 2>/dev/null | head -1)
        if [[ -n "$react_dir" ]] && [[ "$react_dir" != "./e2e-tests" ]]; then
            FRONTEND_DIR="${react_dir#./}"
            log_success "Found React frontend in: $FRONTEND_DIR/"
        else
            log_warning "No React frontend found (skipping frontend setup)"
        fi
    fi

    # Check for e2e-tests (Playwright)
    if [[ -d "e2e-tests" ]] && [[ -f "e2e-tests/package.json" ]]; then
        if grep -q "@playwright/test" "e2e-tests/package.json" 2>/dev/null; then
            E2E_DIR="e2e-tests"
            log_success "Found Playwright E2E tests in: e2e-tests/"
        fi
    else
        # Try to find Playwright project in other locations
        local e2e_dir=$(find . -maxdepth 2 -name "package.json" -exec sh -c 'grep -q "@playwright/test" "$1" && dirname "$1"' _ {} \; 2>/dev/null | head -1)
        if [[ -n "$e2e_dir" ]]; then
            E2E_DIR="${e2e_dir#./}"
            log_success "Found Playwright E2E tests in: $E2E_DIR/"
        else
            log_warning "No Playwright E2E tests found (skipping E2E setup)"
        fi
    fi
}

# ==============================================================================
# PHASE 2: VALIDATION
# ==============================================================================

validate_prerequisites() {
    log_info "Validating prerequisites..."

    cd "$TARGET_DIR"

    # Check git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository. Please run 'git init' in $TARGET_DIR first."
        exit 1
    fi
    log_success "Git repository detected"

    # Check Python (required for backend)
    if [[ -n "$BACKEND_DIR" ]]; then
        if ! command -v python3 &> /dev/null; then
            log_error "Python 3 not found. Please install Python 3."
            exit 1
        fi
        log_success "Python 3 found: $(python3 --version)"
    fi

    # Check Node/npm (required for frontend/e2e)
    if [[ -n "$FRONTEND_DIR" ]] || [[ -n "$E2E_DIR" ]]; then
        if ! command -v npm &> /dev/null; then
            log_error "npm not found. Please install Node.js and npm."
            exit 1
        fi
        log_success "npm found: $(npm --version)"
    fi

    # Check template directory exists
    if [[ ! -d "$TEMPLATE_DIR" ]]; then
        log_error "QA configuration library not found: $TEMPLATE_DIR"
        log_error "Please ensure .hook-templates directory exists in the same location as this script."
        exit 1
    fi
    log_success "QA configuration library found"
}

# ==============================================================================
# PHASE 3: UNINSTALL (Idempotency)
# ==============================================================================

uninstall_existing_hooks() {
    log_info "Removing existing hooks (if any)..."

    cd "$TARGET_DIR"

    # Remove existing hooks and configs
    # Make hook scripts writable first (they are read-only)
    [[ -d ".hooks" ]] && chmod -R u+w .hooks 2>/dev/null || true
    rm -rf .hooks
    rm -f .pre-commit-config.yaml
    rm -rf .semgrep
    rm -f .gitleaks.toml
    rm -f .jscpdrc
    rm -f .jscpdignore
    rm -f .semgrepignore

    # Uninstall pre-commit hooks
    if command -v pre-commit &> /dev/null; then
        pre-commit uninstall 2>/dev/null || true
    fi

    log_success "Cleanup complete"
}

# ==============================================================================
# PHASE 4: COPY FILES
# ==============================================================================

copy_hook_files() {
    log_info "Copying hook files and configurations..."

    cd "$TARGET_DIR"

    # Copy hook scripts
    mkdir -p .hooks
    cp "$TEMPLATE_DIR/hooks"/*.sh .hooks/
    chmod 555 .hooks/*.sh
    log_success "Hook scripts copied to .hooks/ (read-only)"

    # Copy config files
    cp "$TEMPLATE_DIR/configs/.pre-commit-config.yaml" .
    cp "$TEMPLATE_DIR/configs/.gitleaks.toml" .
    cp "$TEMPLATE_DIR/configs/.jscpdrc" .
    log_success "Config files copied to project root"

    # Copy semgrep rules
    mkdir -p .semgrep
    cp "$TEMPLATE_DIR/configs/semgrep-base.yml" .semgrep/base.yml
    cp "$TEMPLATE_DIR/configs/semgrep-e2e.yml" .semgrep/e2e.yml
    log_success "Semgrep rules copied to .semgrep/"
}

# ==============================================================================
# PHASE 5: BACKEND SETUP
# ==============================================================================

setup_backend_qa() {
    log_info "Setting up backend QA tools..."

    cd "$TARGET_DIR/$BACKEND_DIR"

    # Store absolute paths
    local VENV_PATH="$(pwd)/.venv"
    local VENV_PYTHON="$VENV_PATH/bin/python"
    local VENV_PIP="$VENV_PATH/bin/pip"

    # Detect or create virtual environment
    if [[ ! -d ".venv" ]]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv .venv
        log_success "Virtual environment created at: $VENV_PATH"
    else
        log_success "Using existing virtual environment at: $VENV_PATH"
    fi

    # Verify venv exists
    if [[ ! -f "$VENV_PYTHON" ]]; then
        log_error "Virtual environment Python not found at: $VENV_PYTHON"
        return 1
    fi

    # Install QA dependencies using venv's pip directly (no activation needed)
    log_info "Installing QA dependencies (this may take a few minutes)..."

    # Upgrade pip first
    if ! "$VENV_PIP" install --upgrade pip > /dev/null 2>&1; then
        log_error "Failed to upgrade pip"
        return 1
    fi

    # Install requirements with visible output
    log_info "Installing packages from requirements-qa.txt..."
    if ! "$VENV_PIP" install -r "$TEMPLATE_DIR/backend-configs/requirements-qa.txt"; then
        log_error "Failed to install QA dependencies"
        log_error "Check the error messages above for details"
        return 1
    fi

    # Verify critical tools are installed
    log_info "Verifying installation..."
    for tool in ruff mypy pytest semgrep; do
        if [[ ! -f "$VENV_PATH/bin/$tool" ]]; then
            log_error "$tool was not installed correctly in venv"
            return 1
        fi
    done

    log_success "QA dependencies installed and verified in: $VENV_PATH"

    # Merge pyproject.toml configurations
    if [[ -f "pyproject.toml" ]]; then
        log_info "Merging pyproject.toml configurations..."
        python3 "$SCRIPT_DIR/merge-config.py" \
            pyproject.toml \
            "$TEMPLATE_DIR/backend-configs/pyproject-additions.toml" \
            -o pyproject.toml
        log_success "pyproject.toml updated"
    else
        log_warning "No pyproject.toml found, copying template..."
        cp "$TEMPLATE_DIR/backend-configs/pyproject-additions.toml" pyproject.toml
        log_success "pyproject.toml created"
    fi

    # Deactivate venv
    deactivate 2>/dev/null || true

    log_success "Backend QA setup complete"
}

# ==============================================================================
# PHASE 6: FRONTEND SETUP
# ==============================================================================

setup_frontend_qa() {
    log_info "Setting up frontend QA tools..."

    cd "$TARGET_DIR/$FRONTEND_DIR"

    # Merge package.json dependencies
    if [[ -f "package.json" ]]; then
        log_info "Merging package.json devDependencies..."
        python3 "$SCRIPT_DIR/merge-config.py" \
            package.json \
            "$TEMPLATE_DIR/frontend-configs/package-additions.json" \
            -o package.json
        log_success "package.json updated"
    else
        log_error "No package.json found in $FRONTEND_DIR/"
        return 1
    fi

    # Copy config files
    log_info "Copying frontend config files..."
    cp "$TEMPLATE_DIR/frontend-configs/eslint.config.js" .
    cp "$TEMPLATE_DIR/frontend-configs/vite.config.ts" .
    cp "$TEMPLATE_DIR/frontend-configs/vitest.config.ts" .
    cp "$TEMPLATE_DIR/frontend-configs/dependency-cruiser.cjs" .
    cp "$TEMPLATE_DIR/frontend-configs/stylelint.config.json" .
    cp "$TEMPLATE_DIR/frontend-configs/prettierrc.cjs" .prettierrc.cjs
    cp "$TEMPLATE_DIR/frontend-configs/knip.json" .

    # Configure ports in vite.config.ts
    log_info "Configuring ports in vite.config.ts..."
    sed -i.bak "s/__BACKEND_PORT__/$BACKEND_PORT/g" vite.config.ts
    rm -f vite.config.ts.bak

    # Copy tsconfig files
    [[ -f "$TEMPLATE_DIR/frontend-configs/tsconfig-additions.json" ]] && \
        cp "$TEMPLATE_DIR/frontend-configs/tsconfig-additions.json" tsconfig.json
    [[ -f "$TEMPLATE_DIR/frontend-configs/tsconfig.app.json" ]] && \
        cp "$TEMPLATE_DIR/frontend-configs/tsconfig.app.json" .
    [[ -f "$TEMPLATE_DIR/frontend-configs/tsconfig.node.json" ]] && \
        cp "$TEMPLATE_DIR/frontend-configs/tsconfig.node.json" .

    log_success "Config files copied"

    # Install dependencies
    log_info "Installing npm dependencies (this may take a while)..."
    if ! npm install; then
        log_error "Failed to install npm dependencies"
        log_error "Check the error messages above for details"
        return 1
    fi

    # Verify critical tools are available
    log_info "Verifying frontend tools..."
    if ! npx eslint --version > /dev/null 2>&1; then
        log_error "ESLint was not installed correctly"
        return 1
    fi
    if ! npx tsc --version > /dev/null 2>&1; then
        log_error "TypeScript was not installed correctly"
        return 1
    fi

    log_success "npm dependencies installed and verified"
    log_success "Frontend QA setup complete"
}

# ==============================================================================
# PHASE 7: E2E SETUP
# ==============================================================================

setup_e2e_qa() {
    log_info "Setting up E2E QA tools..."

    cd "$TARGET_DIR/$E2E_DIR"

    # Merge package.json dependencies
    if [[ -f "package.json" ]]; then
        log_info "Merging package.json devDependencies..."
        python3 "$SCRIPT_DIR/merge-config.py" \
            package.json \
            "$TEMPLATE_DIR/e2e-configs/package-additions.json" \
            -o package.json
        log_success "package.json updated"
    else
        log_error "No package.json found in $E2E_DIR/"
        return 1
    fi

    # Copy config files
    log_info "Copying E2E config files..."
    cp "$TEMPLATE_DIR/e2e-configs/eslint.config.js" .
    cp "$TEMPLATE_DIR/e2e-configs/playwright.config.ts" .
    [[ -f "$TEMPLATE_DIR/e2e-configs/tsconfig-additions.json" ]] && \
        cp "$TEMPLATE_DIR/e2e-configs/tsconfig-additions.json" tsconfig.json

    # Configure ports in playwright.config.ts
    log_info "Configuring ports in playwright.config.ts..."
    sed -i.bak "s/__BACKEND_PORT__/$BACKEND_PORT/g" playwright.config.ts
    sed -i.bak "s/__FRONTEND_PORT__/$FRONTEND_PORT/g" playwright.config.ts
    rm -f playwright.config.ts.bak

    log_success "Config files copied"

    # Install dependencies
    log_info "Installing npm dependencies..."
    if ! npm install; then
        log_error "Failed to install npm dependencies"
        log_error "Check the error messages above for details"
        return 1
    fi

    # Verify Playwright is installed
    if ! npx playwright --version > /dev/null 2>&1; then
        log_error "Playwright was not installed correctly"
        return 1
    fi

    log_success "npm dependencies installed and verified"

    # Install Playwright browsers
    log_info "Installing Playwright browsers (chromium)..."
    if ! npx playwright install --with-deps chromium; then
        log_warning "Failed to install Playwright browsers with dependencies"
        log_warning "You may need to run: cd $E2E_DIR && npx playwright install --with-deps"
    else
        log_success "Playwright browsers installed"
    fi

    log_success "E2E QA setup complete"
}

# ==============================================================================
# PHASE 8: PRE-COMMIT INSTALLATION
# ==============================================================================

install_precommit_framework() {
    log_info "Installing pre-commit framework..."

    cd "$TARGET_DIR"

    # Check if pre-commit is installed
    if ! command -v pre-commit &> /dev/null; then
        log_info "Installing pre-commit globally..."
        pip install --user pre-commit
    fi

    # Install pre-commit hooks
    log_info "Installing pre-commit hooks..."
    pre-commit install
    log_success "Pre-commit hooks installed"

    # Run pre-commit on all files (optional validation)
    log_info "Running pre-commit validation (this may take a while)..."
    if pre-commit run --all-files; then
        log_success "Pre-commit validation passed"
    else
        log_warning "Pre-commit validation found issues (expected on first run)"
        log_warning "Run 'pre-commit run --all-files' to fix issues"
    fi
}

# ==============================================================================
# PHASE 9: VALIDATION
# ==============================================================================

validate_installation() {
    log_info "Validating installation..."

    cd "$TARGET_DIR"

    local all_good=true

    # Check hook files
    if [[ -d ".hooks" ]] && [[ $(find .hooks -name "*.sh" | wc -l) -eq 7 ]]; then
        log_success "All 7 hook scripts present"
    else
        log_error "Hook scripts missing or incomplete"
        all_good=false
    fi

    # Check config files
    local configs=(".pre-commit-config.yaml" ".gitleaks.toml" ".jscpdrc")
    for config in "${configs[@]}"; do
        if [[ -f "$config" ]]; then
            log_success "Config file present: $config"
        else
            log_error "Config file missing: $config"
            all_good=false
        fi
    done

    # Check semgrep rules
    if [[ -d ".semgrep" ]] && [[ -f ".semgrep/base.yml" ]] && [[ -f ".semgrep/e2e.yml" ]]; then
        log_success "Semgrep rules present"
    else
        log_error "Semgrep rules missing"
        all_good=false
    fi

    # Check backend setup
    if [[ -n "$BACKEND_DIR" ]]; then
        if [[ -f "$BACKEND_DIR/.venv/bin/activate" ]]; then
            log_success "Backend virtual environment created"
        else
            log_error "Backend virtual environment missing"
            all_good=false
        fi
    fi

    if $all_good; then
        log_success "Installation validation passed"
    else
        log_error "Installation validation failed"
        return 1
    fi
}

# ==============================================================================
# PORT CONFIGURATION
# ==============================================================================

configure_ports() {
    # Default ports
    BACKEND_PORT=8000
    FRONTEND_PORT=5173

    log_info "Port Configuration"
    echo ""

    # Configure backend port
    if [[ -n "$BACKEND_DIR" ]] || [[ -n "$E2E_DIR" ]]; then
        echo -e "  Backend API port (Django default): ${BOLD}8000${NC}"
        read -p "  Use default port 8000? [Y/n]: " -r BACKEND_REPLY
        if [[ "$BACKEND_REPLY" =~ ^[Nn]$ ]]; then
            read -p "  Enter custom backend port: " BACKEND_PORT
        fi
        log_success "Backend API port: $BACKEND_PORT"
    fi

    # Configure frontend port
    if [[ -n "$FRONTEND_DIR" ]] || [[ -n "$E2E_DIR" ]]; then
        echo -e "  Frontend dev server port (Vite default): ${BOLD}5173${NC}"
        read -p "  Use default port 5173? [Y/n]: " -r FRONTEND_REPLY
        if [[ "$FRONTEND_REPLY" =~ ^[Nn]$ ]]; then
            read -p "  Enter custom frontend port: " FRONTEND_PORT
        fi
        log_success "Frontend dev server port: $FRONTEND_PORT"
    fi

    echo ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        log_error "Usage: $0 <target-directory>"
        log_error "Example: $0 /path/to/your/project"
        exit 1
    fi

    TARGET_DIR="$1"

    # Validate target directory exists
    if [[ ! -d "$TARGET_DIR" ]]; then
        log_error "Target directory does not exist: $TARGET_DIR"
        exit 1
    fi

    # Convert to absolute path
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA} ▄▄▄       ██▓    ${CYAN}█████   ▄▄▄      ${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA}▒████▄    ▓██▒   ${CYAN}▒██▓  ██▒████▄    ${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA}▒██  ▀█▄  ▒██▒   ${CYAN}▒██▒  ██▒██  ▀█▄  ${NC}   ${BOLD}Code Quality Enforcement${NC}   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA}░██▄▄▄▄██ ░██░   ${CYAN}░██  █▀ ░██▄▄▄▄██ ${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA} ▓█   ▓██▒░██░   ${CYAN}░▒███▒█▄ ▓█   ▓██▒${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA} ▒▒   ▓▒█░░▓     ${CYAN}░░ ▒▒░ ▒ ▒▒   ▓▒█░${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA}  ▒   ▒▒ ░ ▒ ░   ${CYAN} ░ ▒░  ░  ▒   ▒▒ ░${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${MAGENTA}  ░   ▒    ▒ ░   ${CYAN}   ░   ░  ░   ▒   ${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        ${GREEN}Enterprise-Grade QA for AI-Generated Codebases${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo ""
    log_info "Target directory: $TARGET_DIR"
    echo ""

    detect_project_folders
    validate_prerequisites

    echo ""
    echo "Detected configuration:"
    echo "  Backend:  ${BACKEND_DIR:-Not found}"
    echo "  Frontend: ${FRONTEND_DIR:-Not found}"
    echo "  E2E:      ${E2E_DIR:-Not found}"
    echo ""

    # Configure ports
    configure_ports

    # Confirm with user
    read -p "Proceed with installation? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Installation cancelled by user"
        exit 0
    fi

    echo ""
    uninstall_existing_hooks
    copy_hook_files

    [[ -n "$BACKEND_DIR" ]] && setup_backend_qa
    [[ -n "$FRONTEND_DIR" ]] && setup_frontend_qa
    [[ -n "$E2E_DIR" ]] && setup_e2e_qa

    install_precommit_framework
    validate_installation

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     ${BOLD}${GREEN}✓${NC} ${BOLD}Enterprise-Grade QA Enforcement Activated!${NC}                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your AI-generated codebase is now protected by:"
    echo "  ✓ 55+ quality enforcement rules"
    echo "  ✓ Zero-tolerance security scanning"
    echo "  ✓ Strict type safety enforcement"
    echo "  ✓ 90% test coverage requirement"
    echo "  ✓ Automated accessibility checks"
    echo ""
    echo "Next steps:"
    echo "  1. Review installed hooks: .hooks/"
    echo "  2. Test enforcement: git add . && git commit -m 'test'"
    echo "  3. Run manual QA checks:"
    [[ -n "$BACKEND_DIR" ]] && echo "     - Backend: cd $BACKEND_DIR && source .venv/bin/activate && pytest"
    [[ -n "$FRONTEND_DIR" ]] && echo "     - Frontend: cd $FRONTEND_DIR && npm test"
    [[ -n "$E2E_DIR" ]] && echo "     - E2E: cd $E2E_DIR && npm test"
    echo ""
    echo "All commits will now be validated against production-grade standards."
    echo ""
}

# Run main function
main "$@"
