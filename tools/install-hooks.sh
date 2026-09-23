#!/bin/bash
# Point git at the versioned hooks in .githooks/ (build + gate on commit,
# push + deploy after a commit to main). Run once per clone.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/*
git config core.hooksPath .githooks
echo "hooks installed: $(ls .githooks | tr '\n' ' ')"
