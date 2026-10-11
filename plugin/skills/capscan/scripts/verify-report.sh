#!/usr/bin/env bash
# Verifies a capscan report before anyone sees it:
# every cited `path:line` must exist in a file the repository tracks, and every link must use an allowed host.
# Usage: verify-report.sh <report> <allowed-host>...
set -euo pipefail

report=$1
shift
[ -s "$report" ] || exit 0

# A citation must point at a file in the repository. Generated files, such as the facts in
# capscan-input/, exist where the agent runs but not where a reader looks, so they do not count.
tracked() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files --error-unmatch -- "$1" >/dev/null 2>&1
  else
    [ -f "$1" ]
  fi
}

status=0
# Citations are `path:line` or `path:start-end`; a range is checked against its last line.
while IFS=: read -r path lines; do
  last=${lines#*-}
  if ! tracked "$path"; then
    echo "::error::report cites $path:$lines, which is not a file in this repository"
    status=1
  elif [ "$(awk 'END { print NR }' "$path")" -lt "$last" ]; then
    echo "::error::report cites $path:$lines, which does not exist"
    status=1
  fi
done < <(grep -oE '`[A-Za-z0-9_./-]+:[0-9]+(-[0-9]+)?`' "$report" | tr -d '`' | sort -u)

while read -r host; do
  allowed=0
  for ok in "$@"; do
    [ "$host" = "$ok" ] && allowed=1
  done
  if [ "$allowed" -eq 0 ]; then
    echo "::error::report links to $host, which is outside the allowlist"
    status=1
  fi
done < <(grep -oE 'https?://[^/[:space:])>`]+' "$report" | sed -E 's#^https?://##' | sort -u)

exit $status
