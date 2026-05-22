#!/usr/bin/env bash
# Probe the current directory and emit a JSON summary the agent can use
# to decide what to do during Alchemy setup. Read-only.
# Usage: scripts/detect_project.sh [dir]
set -euo pipefail

DIR="${1:-.}"
cd "$DIR"

has() { [ -e "$1" ] && echo true || echo false; }

PM="unknown"
if [ -f bun.lockb ] || [ -f bun.lock ]; then PM="bun"
elif [ -f pnpm-lock.yaml ]; then PM="pnpm"
elif [ -f yarn.lock ]; then PM="yarn"
elif [ -f package-lock.json ]; then PM="npm"
fi

FRAMEWORK="none"
if [ -f package.json ]; then
  if   grep -q '"next"'             package.json 2>/dev/null; then FRAMEWORK="nextjs"
  elif grep -q '"@sveltejs/kit"'    package.json 2>/dev/null; then FRAMEWORK="sveltekit"
  elif grep -q '"astro"'            package.json 2>/dev/null; then FRAMEWORK="astro"
  elif grep -q '"nuxt"'             package.json 2>/dev/null; then FRAMEWORK="nuxt"
  elif grep -q '"@tanstack/start"'  package.json 2>/dev/null; then FRAMEWORK="tanstack-start"
  elif grep -q '"react-router"'     package.json 2>/dev/null; then FRAMEWORK="react-router"
  elif grep -q '"vite"'             package.json 2>/dev/null; then FRAMEWORK="vite"
  fi
fi

ALCHEMY_INSTALLED=false
if [ -f package.json ] && grep -q '"alchemy"' package.json 2>/dev/null; then
  ALCHEMY_INSTALLED=true
fi

cat <<EOF
{
  "package_json":      $(has package.json),
  "tsconfig":          $(has tsconfig.json),
  "alchemy_run_ts":    $(has alchemy.run.ts),
  "alchemy_installed": $ALCHEMY_INSTALLED,
  "wrangler_toml":     $(has wrangler.toml),
  "wrangler_jsonc":    $(has wrangler.jsonc),
  "sst_config":        $(has sst.config.ts),
  "pulumi_yaml":       $(has Pulumi.yaml),
  "cdk_json":          $(has cdk.json),
  "env_file":          $(has .env),
  "env_example":       $(has .env.example),
  "gitignore":         $(has .gitignore),
  "git_repo":          $([ -d .git ] && echo true || echo false),
  "package_manager":   "$PM",
  "framework":         "$FRAMEWORK"
}
EOF
