#!/usr/bin/env bash
set -euo pipefail

# Backend fast guard: silent on success; fail-fast with hints
# CRITICAL: All tools MUST use backend/.venv/bin/* to ensure isolation

# 1) Ruff lint & format check
out=$(backend/.venv/bin/ruff check backend --output-format=concise 2>&1) || { printf "%s\n" "$out"; echo "Hint: Fix Ruff issues (style, bugs, imports)." >&2; exit 1; }
out=$(backend/.venv/bin/ruff format --check backend --quiet 2>&1) || { printf "%s\n" "$out"; echo "Hint: Code format mismatch. Run: backend/.venv/bin/ruff format backend" >&2; exit 1; }

# 2) Unused imports/variables check
out=$(backend/.venv/bin/autoflake --check --recursive --remove-all-unused-imports --remove-unused-variables --exclude=__pycache__,.venv,migrations backend 2>&1) || { printf "%s\n" "$out"; echo "Hint: Remove unused imports/variables. Run: backend/.venv/bin/autoflake --in-place --recursive --remove-all-unused-imports --remove-unused-variables backend" >&2; exit 1; }

# 3) MyPy strict (with Django stubs)
out=$(backend/.venv/bin/mypy --strict backend 2>&1) || { printf "%s\n" "$out"; echo "Hint: Add/adjust type annotations to satisfy mypy --strict." >&2; exit 1; }

# 4) Complexity check (max 10 per function, B average)
out=$(backend/.venv/bin/xenon --max-absolute B --max-modules B --max-average A --exclude backend/.venv,backend/migrations backend 2>&1) || { printf "%s\n" "$out"; echo "Hint: Reduce function complexity (max cyclomatic complexity: 10). Refactor complex functions." >&2; exit 1; }

# 5) Bandit security scan
out=$(backend/.venv/bin/bandit -r backend -ll --exclude backend/.venv 2>&1) || { printf "%s\n" "$out"; echo "MANDATORY: Fix all Bandit security findings. Suppressing findings with # nosec is ONLY allowed for verified false positives with documented justification. NEVER suppress real security issues." >&2; exit 1; }

# 6) Django system checks
out=$(backend/.venv/bin/python backend/manage.py check --fail-level WARNING 2>&1) || { printf "%s\n" "$out"; echo "Hint: Fix Django system check warnings/errors." >&2; exit 1; }

# 7) Architecture: Import linting
out=$(cd backend && ./.venv/bin/lint-imports 2>&1) || { printf "%s\n" "$out"; echo "Hint: Fix import layer violations (check pyproject.toml [tool.importlinter])." >&2; exit 1; }

# 8) Test coverage (90% minimum, branch coverage)
out=$(cd backend && ./.venv/bin/pytest --cov=. --cov-report=term-missing:skip-covered --cov-fail-under=90 --cov-branch -q 2>&1) || { printf "%s\n" "$out"; echo "Test failure detected. FIRST: Fix all failing tests - they must pass. SECOND: Add tests to reach minimum 90% coverage. DO NOT lower coverage thresholds. DO NOT exclude files from coverage to game metrics." >&2; exit 1; }

# 9) Dependency vulnerability scanning
out=$(backend/.venv/bin/pip-audit 2>&1) || { printf "%s\n" "$out"; echo "CRITICAL: Update all vulnerable dependencies immediately. Marking as false positive is ONLY permitted after thorough security review proving no exploitability. Document justification. When in doubt, update." >&2; exit 1; }

# 10) Django migrations check
out=$(backend/.venv/bin/python backend/manage.py makemigrations --check --dry-run 2>&1) || { printf "%s\n" "$out"; echo "Hint: Unapplied model changes detected. Run makemigrations." >&2; exit 1; }

# 11) Max lines enforcement (400 prod, 600 tests)
"$(dirname "$0")/backend-max-lines.sh" >/dev/null || exit 1

# 12) Dead code detection
out=$(cd backend && ./.venv/bin/vulture . 2>&1) || { printf "%s\n" "$out"; echo "Unused code found. MANDATORY: Remove all dead code. NEVER whitelist to avoid fixing the issue. Whitelist exceptions require justification: Django framework methods, signal handlers, dynamic code execution, or public API surface. Prefer refactoring over whitelisting. When in doubt, delete." >&2; exit 1; }

# 13) Bypass directive enforcement
"$(dirname "$0")/check-bypass-directives.sh" || exit 1

exit 0
