#!/usr/bin/env bash
set -euo pipefail

base="${1:-$(tr -d '[:space:]' < .upstream-base)}"
new="${2:-}"

if [[ -z "$new" ]]; then
  echo "usage: $0 [base_sha] <new_sha>" >&2
  exit 2
fi

upstream_url="https://github.com/GangYe293/wordgloss.koplugin.git"

if git remote get-url upstream >/dev/null 2>&1; then
  git remote set-url upstream "$upstream_url"
else
  git remote add upstream "$upstream_url"
fi

git fetch --no-tags upstream main
git cat-file -e "$base^{commit}"
git cat-file -e "$new^{commit}"

if ! git merge-base --is-ancestor "$base" "$new"; then
  echo "ERROR: NEW_SHA is not a descendant of BASE_SHA" >&2
  exit 3
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git diff --name-only "$base..$new" | sort -u > "$tmp/upstream-files"
git diff --name-only "$base..HEAD" | sort -u > "$tmp/downstream-files"
comm -12 "$tmp/upstream-files" "$tmp/downstream-files" > "$tmp/overlap-files"

echo "base_sha=$base"
echo "new_sha=$new"
echo
echo "[upstream changed files]"
cat "$tmp/upstream-files"
echo
echo "[downstream changed files since base]"
cat "$tmp/downstream-files"
echo
echo "[file overlap]"
cat "$tmp/overlap-files"
echo
printf 'upstream_file_count=%s\n' "$(wc -l < "$tmp/upstream-files" | tr -d ' ')"
printf 'downstream_file_count=%s\n' "$(wc -l < "$tmp/downstream-files" | tr -d ' ')"
printf 'overlap_file_count=%s\n' "$(wc -l < "$tmp/overlap-files" | tr -d ' ')"
