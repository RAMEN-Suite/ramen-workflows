#!/usr/bin/env bash
set -euo pipefail

dir=$(mktemp -d "$RUNNER_TEMP/ssh-setup.XXXXXX")
printf '%s\n' "$SSH_KNOWN_HOSTS" >"$dir/known_hosts"

eval "$(env -u SSH_PRIVATE_KEY ssh-agent -a "$dir/agent.sock" -s)" >/dev/null
printf '%s\n' "$SSH_PRIVATE_KEY" | ssh-add -q -

cat >"$dir/config" <<CONFIG
Host deploy-target
  HostName $SSH_HOST
  User $SSH_USER
  IdentityAgent "$dir/agent.sock"
  UserKnownHostsFile "$dir/known_hosts"
  StrictHostKeyChecking yes
  BatchMode yes
  ConnectTimeout 20
  ServerAliveInterval 30
CONFIG

echo "config=$dir/config" >>"$GITHUB_OUTPUT"
