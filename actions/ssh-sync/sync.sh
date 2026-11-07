#!/usr/bin/env bash
set -euo pipefail

if ! jq -e 'type == "array" and length > 0' <<<"$TRANSFERS" >/dev/null 2>&1; then
  echo "::error::transfers must be a non-empty JSON list"
  exit 1
fi

rerun=false
if [ "${GITHUB_RUN_ATTEMPT:-1}" -gt 1 ]; then rerun=true; fi

restart=""
up=""
while IFS= read -r transfer; do
  from=$(jq -r '.from' <<<"$transfer")
  to=$(jq -r '.to' <<<"$transfer")
  mapfile -t paths < <(jq -r '.paths[]' <<<"$transfer")
  args=(--recursive --compress --checksum --mkpath --itemize-changes)
  if [ "$(jq -r '.delete // false' <<<"$transfer")" = true ]; then
    args+=(--delete)
  fi

  echo "::group::$from -> $to"
  changes=$(cd "$from" && rsync "${args[@]}" -e "ssh -F $SSH_CONFIG" -- "${paths[@]}" "deploy-target:$to")
  if [ -n "$changes" ]; then
    printf '%s\n' "$changes"
  else
    echo "Unchanged."
  fi
  if [ -n "$changes" ] || [ "$rerun" = true ]; then
    restart+="$(jq -r '.restart // [] | .[]' <<<"$transfer")"$'\n'
    up+="$(jq -r '.up // [] | .[]' <<<"$transfer")"$'\n'
  fi
  echo "::endgroup::"
done < <(jq -c '.[]' <<<"$TRANSFERS")

{
  echo "restart<<EOF"
  printf '%s' "$restart" | sort -u | sed '/^$/d'
  echo "EOF"
  echo "up<<EOF"
  printf '%s' "$up" | sort -u | sed '/^$/d'
  echo "EOF"
} >>"$GITHUB_OUTPUT"
