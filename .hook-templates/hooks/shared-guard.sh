#!/usr/bin/env bash
set -euo pipefail

# Shared guard: secrets, semgrep (base + overlays), duplication, formatting
# Excludes: node_modules, dist, build, .venv, venv, coverage, .tmp, e2e-tests/test-results

# 1) Gitleaks (quiet on success)
out=$(bash -lc 'gitleaks detect --redact --config .gitleaks.toml --log-level=error --no-banner' 2>&1) || { printf "%s\n" "$out"; exit 1; }

# 2) Semgrep base + overlays (prod + e2e)
command -v backend/.venv/bin/semgrep >/dev/null 2>&1 || { echo "semgrep not found in backend venv" >&2; exit 1; }
backend/.venv/bin/semgrep --config .semgrep/base.yml --config .semgrep/e2e.yml --error --quiet --exclude node_modules --exclude dist --exclude build --exclude .venv --exclude venv --exclude coverage --exclude .tmp --exclude e2e-tests/test-results || { echo "Semgrep detected code issues. MANDATORY: Fix all violations by refactoring code. DO NOT suppress with 'nosemgrep' comments unless verified false positive with documented justification. Semgrep catches security issues, bugs, and anti-patterns - fix the root cause." >&2; exit 1; }

# 3) Duplication gate
./frontend/node_modules/.bin/jscpd --config .jscpdrc frontend/src e2e-tests/tests >/dev/null || { echo "Code duplication detected. MANDATORY: Extract duplicated logic into shared functions/modules. DO NOT ignore this check. DO NOT add jscpd ignore comments. DRY (Don't Repeat Yourself) is non-negotiable for maintainability." >&2; exit 1; }

# 4) Prettier formatting checks (strict)
./frontend/node_modules/.bin/prettier --check "frontend/src/**/*.{ts,tsx,css}" >/dev/null || { echo "Hint: Run Prettier on frontend/src." >&2; exit 1; }
./frontend/node_modules/.bin/prettier --check "e2e-tests/**/*.{ts,tsx,js}" >/dev/null || { echo "Hint: Run Prettier on e2e-tests." >&2; exit 1; }

exit 0
