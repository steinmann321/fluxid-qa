#!/opt/homebrew/bin/bash
# Logging and output functions

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
    printf "${BLUE}ℹ${NC} %s\n" "$1" >&2
}

log_success() {
    printf "${GREEN}✓${NC} %s\n" "$1" >&2
}

log_warning() {
    printf "${YELLOW}⚠${NC} %s\n" "$1" >&2
}

log_error() {
    printf "${RED}✗${NC} %s\n" "$1" >&2
}

print_header() {
    printf "\n"
    printf "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}   ${BOLD}${MAGENTA}fluxid qa - Modular Component System${NC}                         ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}                                                                      ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}        ${GREEN}Enterprise-Grade QA for Multiple Tech Stacks${NC}             ${CYAN}║${NC}\n"
    printf "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
}

get_component_description() {
    local component=$1
    case "$component" in
        shared-v2)
            echo "Core configs (pre-commit, gitleaks, semgrep, jscpd)"
            ;;
        backend/django-v2)
            echo "Backend QA (ruff, mypy, pytest, bandit, vulture, pip-audit)"
            ;;
        backend/django)
            echo "Backend QA (Django)"
            ;;
        backend/go-v2)
            echo "Backend QA (golangci-lint, gosec, go test)"
            ;;
        backend/go)
            echo "Backend QA (Go)"
            ;;
        frontend/react-v2)
            echo "Frontend QA (TypeScript, ESLint, vitest, knip, dependency-cruiser)"
            ;;
        frontend/react)
            echo "Frontend QA (React)"
            ;;
        e2e/playwright-v2)
            echo "E2E QA (Playwright tests, TypeScript checks)"
            ;;
        e2e/playwright)
            echo "E2E QA (Playwright)"
            ;;
        shared)
            echo "Shared configs"
            ;;
        *)
            echo "$component"
            ;;
    esac
}

print_success_footer() {
    local components=("$@")

    printf "\n"
    printf "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${GREEN}║${NC}                                                                      ${GREEN}║${NC}\n"
    printf "${GREEN}║${NC}     ${BOLD}${GREEN}✓${NC} ${BOLD}Enterprise-Grade QA Enforcement Activated!${NC}                  ${GREEN}║${NC}\n"
    printf "${GREEN}║${NC}                                                                      ${GREEN}║${NC}\n"
    printf "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
    printf "Installed components:\n"
    for component in "${components[@]}"; do
        local description=$(get_component_description "$component")
        printf "  ✓ %s\n" "$description"
    done
    printf "\n"
    printf "Next steps:\n"
    printf "  1. Review installed hooks: .hooks/\n"
    printf "  2. Test enforcement: /usr/bin/git add . && /usr/bin/git commit -m 'test'\n"
    printf "\n"
}
