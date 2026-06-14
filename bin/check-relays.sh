#!/usr/bin/env bash
# Verifie et relance les relais socat utilises par act.

set -euo pipefail

RELAYS=(
  "4873:verdaccio:4873"
  "5000:registry:5000"
  "2222:ssh-npm-target:22"
  "2223:ssh-docker-target:22"
  "3001:ssh-npm-target:3000"
  "3002:ssh-docker-target:3000"
)

relay_ok() {
  local port=$1
  pgrep -f "socat TCP-LISTEN:${port}" > /dev/null 2>&1
}

for relay in "${RELAYS[@]}"; do
  local_port="${relay%%:*}"
  target="${relay#*:}"

  if relay_ok "$local_port"; then
    echo "ok socat :${local_port} -> ${target}"
  else
    echo "missing socat :${local_port} -> ${target}; restarting"
    nohup socat "TCP-LISTEN:${local_port},fork,reuseaddr" "TCP:${target}" > /dev/null 2>&1 &
  fi
done

curl -sf http://localhost:4873/-/ping > /dev/null
echo "ok Verdaccio http://localhost:4873"

curl -sf http://localhost:5000/v2/ > /dev/null
echo "ok Docker registry http://localhost:5000/v2/"

ssh -p 2222 -o StrictHostKeyChecking=no -o ConnectTimeout=3 deployer@localhost "echo ok" > /dev/null
echo "ok SSH npm target localhost:2222"

ssh -p 2223 -o StrictHostKeyChecking=no -o ConnectTimeout=3 deployer@localhost "echo ok" > /dev/null
echo "ok SSH Docker target localhost:2223"
