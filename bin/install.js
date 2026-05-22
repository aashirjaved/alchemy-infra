#!/usr/bin/env node
// Install alchemy-infra into a Claude skills directory.
// Usage:
//   npx alchemy-infra install            -> ~/.claude/skills/alchemy-infra
//   npx alchemy-infra install --here     -> ./.claude/skills/alchemy-infra
//   npx alchemy-infra install --to PATH  -> PATH/alchemy-infra

"use strict";
const fs = require("fs");
const path = require("path");
const os = require("os");

const argv = process.argv.slice(2);
const cmd = argv[0] || "install";

if (cmd === "--help" || cmd === "-h" || cmd === "help") {
  console.log(`alchemy-infra — installer

Usage:
  npx alchemy-infra install              Install to ~/.claude/skills/alchemy-infra
  npx alchemy-infra install --here       Install to ./.claude/skills/alchemy-infra
  npx alchemy-infra install --to <dir>   Install to <dir>/alchemy-infra
  npx alchemy-infra uninstall [--here|--to <dir>]
  npx alchemy-infra path [--here|--to <dir>]

After install, the skill loads automatically when an agent reads the directory.`);
  process.exit(0);
}

function resolveTarget(args) {
  const here = args.includes("--here");
  const toIdx = args.indexOf("--to");
  let base;
  if (toIdx !== -1 && args[toIdx + 1]) {
    base = path.resolve(args[toIdx + 1]);
  } else if (here) {
    base = path.resolve(process.cwd(), ".claude", "skills");
  } else {
    base = path.join(os.homedir(), ".claude", "skills");
  }
  return path.join(base, "alchemy-infra");
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      // Skip node_modules, .git, build artifacts
      if (["node_modules", ".git", ".DS_Store"].includes(entry.name)) continue;
      copyDir(s, d);
    } else {
      fs.copyFileSync(s, d);
      // Preserve executable bit for shell scripts
      if (entry.name.endsWith(".sh") || entry.name.endsWith(".js")) {
        try { fs.chmodSync(d, 0o755); } catch {}
      }
    }
  }
}

const target = resolveTarget(argv);
const pkgRoot = path.resolve(__dirname, "..");

if (cmd === "path") {
  console.log(target);
  process.exit(0);
}

if (cmd === "uninstall") {
  if (!fs.existsSync(target)) {
    console.log(`Nothing to uninstall at ${target}`);
    process.exit(0);
  }
  fs.rmSync(target, { recursive: true, force: true });
  console.log(`Removed ${target}`);
  process.exit(0);
}

if (cmd !== "install") {
  console.error(`Unknown command: ${cmd}. Run with --help.`);
  process.exit(2);
}

if (fs.existsSync(target)) {
  if (!argv.includes("--force")) {
    console.error(`Target already exists: ${target}\nRe-run with --force to overwrite.`);
    process.exit(1);
  }
  fs.rmSync(target, { recursive: true, force: true });
}

copyDir(pkgRoot, target);

// Drop the npx-only files from the installed skill (skills don't need them)
for (const drop of ["package.json", "bin", "node_modules"]) {
  const p = path.join(target, drop);
  if (fs.existsSync(p)) fs.rmSync(p, { recursive: true, force: true });
}

console.log(`Installed alchemy-infra to:\n  ${target}\n`);
console.log(`Verify by listing it:\n  ls ${target}\n`);
console.log(`Your agent should now auto-discover the skill on next session.`);
