#!/bin/bash
# Cleanup stale branches and PRs
# Run this locally where you have gh CLI and push access

set -e

echo "=== Closing PRs and deleting merged/superseded branches ==="
echo

# 1. claude/optimize-game-performance-uBfLe — PR #81, fully merged
echo "Closing PR #81 (optimize-game-performance) — already merged..."
gh pr close 81 --comment "Closing: branch was already merged into main via this PR." --delete-branch

# 2. claude/review-game-specs-AEtyt — PR #85, fully merged
echo "Closing PR #85 (review-game-specs) — already merged..."
gh pr close 85 --comment "Closing: branch was already merged into main via this PR." --delete-branch

# 3. claude/refactor-golfer-needs-system-kCLw7 — PR #68, superseded
echo "Closing PR #68 (refactor-golfer-needs) — superseded, 46 commits behind..."
gh pr close 68 --comment "Closing: this work was merged into main through other branches. Branch is 46 commits behind and no longer needed." --delete-branch

echo
echo "=== Done! 3 branches deleted, 3 PRs closed ==="
