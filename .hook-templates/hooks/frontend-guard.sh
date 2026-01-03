#!/usr/bin/env bash
set -euo pipefail

# Frontend production guard: fail-fast static QA & architecture

# 1) Security: npm audit
( cd frontend && npm audit --audit-level=moderate ) >/dev/null || { echo "Hint: Fix npm audit vulnerabilities (moderate+)." >&2; exit 1; }

# 2) Max lines caps: 400 prod, 600 tests
"$(dirname "$0")/frontend-max-lines.sh" >/dev/null

# 3) ESLint
( cd frontend && ./node_modules/.bin/eslint -f unix . --max-warnings=0 ) || { echo "Hint: Fix ESLint errors in frontend." >&2; exit 1; }

# 4) TypeScript typecheck
( cd frontend && ./node_modules/.bin/tsc -b --noEmit ) >/dev/null || { echo "Hint: Fix TypeScript type errors (noEmit)." >&2; exit 1; }

# 5) Type coverage 100%
( cd frontend && ./node_modules/.bin/type-coverage --project tsconfig.app.json --strict --detail --ignore-files "**/*.test.*" "**/*.spec.*" --target 100 --cache-directory ../.tmp/type-coverage/frontend ) >/dev/null || { echo "Hint: Reach 100% type coverage in src/." >&2; exit 1; }

# 6) Test coverage 90% (vitest)
( cd frontend && ./node_modules/.bin/vitest run --coverage --coverage.all ) >/dev/null || { echo "Hint: Add tests to reach 90% coverage or fix failing tests." >&2; exit 1; }

# 7) Production build verification
( cd frontend && ./node_modules/.bin/vite build --mode production ) >/dev/null || { echo "Hint: Fix production build errors." >&2; exit 1; }

# 8) Architecture import rules (depcruise across src)
( cd frontend && ./node_modules/.bin/depcruise --config ./dependency-cruiser.cjs ./src ) >/dev/null || { echo "Hint: Fix depcruise violations (unresolvable, circular, dev-deps)." >&2; exit 1; }

# 9) Unused exports/files (exclude main.tsx - entry point with intentional exports for React Fast Refresh)
( cd frontend && ./node_modules/.bin/ts-unused-exports tsconfig.app.json --showLineNumber --exitWithCount --excludePathsFromReport="src/main.tsx" ) >/dev/null || { echo "Hint: Remove or use unused exports." >&2; exit 1; }
( cd frontend && ./node_modules/.bin/knip --strict ) >/dev/null || { echo "Hint: Remove unused files/exports (knip)." >&2; exit 1; }

# 10) Dependency hygiene
( cd frontend && ./node_modules/.bin/depcheck --ignores "@tailwindcss/postcss,autoprefixer,dependency-cruiser,depcheck,eslint-formatter-unix,jscpd,jsdom,knip,postcss,prettier,prettier-plugin-organize-imports,prettier-plugin-tailwindcss,stylelint,stylelint-config-standard,tailwindcss,ts-unused-exports,type-coverage,vitest,vitest-axe,@vitest/ui,@vitest/coverage-v8,@testing-library/react,@testing-library/jest-dom,@testing-library/user-event" ) >/dev/null || { echo "Hint: Clean unused/incorrect dependencies." >&2; exit 1; }

# 11) CSS lint
( cd frontend && ./node_modules/.bin/stylelint "src/**/*.css" --ignore-path .stylelintignore --allow-empty-input ) >/dev/null || { echo "Hint: Fix Stylelint errors." >&2; exit 1; }

exit 0
