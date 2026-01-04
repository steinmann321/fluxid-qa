#!/usr/bin/env bash
set -euo pipefail

# E2E guard: Playwright QA, anti-flakiness, exact errors only

# 1) ESLint (Playwright strict)
( cd e2e-tests && ./node_modules/.bin/eslint -f unix . --max-warnings=0 ) || { echo "Hint: Fix E2E ESLint errors (locator-first, expect assertions, no networkidle/waitForTimeout/pause)." >&2; exit 1; }

# 2) TypeScript typecheck
( cd e2e-tests && ./node_modules/.bin/tsc --noEmit ) >/dev/null || { echo "Hint: Fix E2E TypeScript type errors." >&2; exit 1; }

# 3) Type coverage 95%
( cd e2e-tests && ./node_modules/.bin/type-coverage --at-least 95 --strict --detail --cache-directory ../.tmp/type-coverage/e2e ) >/dev/null || { echo "Hint: Reach 95% type coverage in E2E tests." >&2; exit 1; }

# 4) Verify credentials
( cd e2e-tests && node verify-credentials.cjs ) >/dev/null || { echo "Hint: Missing/invalid E2E test credentials." >&2; exit 1; }

# 5) Duplication gate for tests
./frontend/node_modules/.bin/jscpd --threshold 0 --gitignore e2e-tests/tests >/dev/null || { echo "Code duplication detected in E2E tests. MANDATORY: Extract duplicated logic into shared functions/modules. DO NOT ignore this check. DO NOT add jscpd ignore comments. DRY (Don't Repeat Yourself) is non-negotiable for maintainability." >&2; exit 1; }

# 6) Max lines cap for tests (600)
FILES=$(find e2e-tests/tests -type f \( -name '*.ts' -o -name '*.tsx' \))
for f in $FILES; do
  lines=$(wc -l < "$f" | tr -d '[:space:]')
  if [ "$lines" -gt 600 ]; then
    echo "Error: $f exceeds limit (600 lines)" >&2
    echo "Hint: Split large tests into smaller focused specs." >&2
    exit 1
  fi
done

exit 0
