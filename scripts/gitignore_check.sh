#!/usr/bin/env bash
# Ensure .gitignore contains the entries required for safe Alchemy use.
# If any are missing, append them (idempotent) and report what was added.
# Usage: scripts/gitignore_check.sh [repo-root]
set -euo pipefail

ROOT="${1:-.}"
GI="$ROOT/.gitignore"
touch "$GI"

REQUIRED=(
  ".env"
  ".env.*"
  "!.env.example"
  ".alchemy/"
  "node_modules/"
  ".wrangler/"
  "dist/"
  ".DS_Store"
  "*.pem"
  "*.key"
  "credentials.json"
)

ADDED=()
for line in "${REQUIRED[@]}"; do
  # exact-line match
  if ! grep -Fxq "$line" "$GI"; then
    echo "$line" >> "$GI"
    ADDED+=("$line")
  fi
done

if [ ${#ADDED[@]} -eq 0 ]; then
  echo ".gitignore OK — all required entries present."
else
  echo "Appended to $GI:"
  printf '  %s\n' "${ADDED[@]}"
fi

# Final safety check: warn if .env or .alchemy is tracked
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  TRACKED=$(git -C "$ROOT" ls-files -- .env .env.* .alchemy 2>/dev/null || true)
  if [ -n "$TRACKED" ]; then
    echo
    echo "DANGER: these sensitive paths are already tracked in git:"
    echo "$TRACKED"
    echo "Run: git rm --cached <path> && git commit -m 'untrack secrets'"
    exit 3
  fi
fi
