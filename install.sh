#!/usr/bin/env bash
#
# Claude Skill Hub — installer / restorer
#
# Usage:   curl -fsSL https://claude-skill-hub.zeabur.app/install.sh | bash -s <skill-name>
# Example: curl -fsSL https://claude-skill-hub.zeabur.app/install.sh | bash -s zeabur-github-deploy
#
# What it does (and ONLY this):
#   - Reads the skill's file list from <hub>/skills/<name>/files.txt
#   - Downloads each listed file into  ~/.claude/skills/<name>/
# It writes nothing outside ~/.claude/skills/<name>/. No sudo. No other side effects.
# You are encouraged to open this script in a browser before piping it to bash.

set -euo pipefail

BASE_URL="${SKILL_HUB_BASE_URL:-https://claude-skill-hub.zeabur.app}"
SKILL="${1:-}"

if [ -z "$SKILL" ]; then
  echo "error: no skill name given" >&2
  echo "usage: curl -fsSL $BASE_URL/install.sh | bash -s <skill-name>" >&2
  exit 1
fi

DEST="$HOME/.claude/skills/$SKILL"
LIST_URL="$BASE_URL/skills/$SKILL/files.txt"

echo "==> Installing skill '$SKILL' from $BASE_URL"

# Fetch the file manifest for this skill.
files="$(curl -fsSL "$LIST_URL")" || {
  echo "error: skill '$SKILL' not found (could not fetch $LIST_URL)" >&2
  exit 1
}

mkdir -p "$DEST"

count=0
while IFS= read -r f; do
  # skip blank lines / comments
  [ -z "$f" ] && continue
  case "$f" in \#*) continue ;; esac
  # subdirectories inside a skill (e.g. references/foo.md) are preserved
  mkdir -p "$DEST/$(dirname "$f")"
  echo "    - $f"
  curl -fsSL "$BASE_URL/skills/$SKILL/$f" -o "$DEST/$f"
  count=$((count + 1))
done <<EOF
$files
EOF

echo "==> Done. Installed $count file(s) to: $DEST"
echo "    Restart Claude Code (or /reload) and the skill '$SKILL' is available."
