#!/usr/bin/env bash
set -euo pipefail

if ! jq -e 'length > 0' <<<"${STACKS:-[]}" >/dev/null; then
  echo "::error::DEPLOY_STACKS is empty or not set for this environment"
  exit 1
fi

for stack in $(jq -r '.[]' <<<"$STACKS"); do
  for service in $(jq -r 'keys_unsorted[]' <<<"$IMAGES"); do
    ref=$(jq -r --arg s "$service" '.[$s]' <<<"$IMAGES")
    echo "Deploying $service $ref to $stack"
    printf '%s' "$TOKEN" | ssh -F "$SSH_CONFIG" deploy-target deploy "$stack" "$service" "$ref"
  done
done
