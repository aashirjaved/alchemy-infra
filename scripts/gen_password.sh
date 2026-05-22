#!/usr/bin/env bash
# Generate a strong ALCHEMY_PASSWORD and append (or update) it in .env.
# Usage: scripts/gen_password.sh [path-to-env-file]
# Default env path: .env in current working directory.
# Never echoes the password to stdout — only confirms the file was written.
set -euo pipefail

ENV_FILE="${1:-.env}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found — install it or generate 32 random bytes another way." >&2
  exit 1
fi

PW=$(openssl rand -base64 32 | tr -d '\n')

touch "$ENV_FILE"
chmod 600 "$ENV_FILE" 2>/dev/null || true

if grep -q '^ALCHEMY_PASSWORD=' "$ENV_FILE"; then
  echo "ALCHEMY_PASSWORD already set in $ENV_FILE — not overwriting." >&2
  echo "If you really want to rotate, remove the line manually first." >&2
  echo "WARNING: rotation breaks decryption of existing state." >&2
  exit 2
fi

printf '\nALCHEMY_PASSWORD=%s\n' "$PW" >> "$ENV_FILE"
unset PW
echo "Wrote ALCHEMY_PASSWORD to $ENV_FILE (32 bytes, base64)."
echo "Reminder: do NOT commit $ENV_FILE. Verify .gitignore."
