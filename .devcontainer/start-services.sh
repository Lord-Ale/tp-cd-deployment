#!/bin/bash
set -euo pipefail

WORKSPACE="/workspaces/tp-cd-deployment"
NETWORK="tp-cd-deployment_cd-network"
SSH_KEY_PATH="$HOME/.ssh/tp_cd_deployment_key"

echo "==> Démarrage des services locaux (registres + cibles SSH)..."
docker compose -f "$WORKSPACE/docker-compose.yml" up -d --build

echo "==> Connexion du DevContainer au réseau Docker cd-network..."
docker network connect "$NETWORK" "$(hostname)" 2>/dev/null || true

echo "==> Démarrage des relais socat (localhost → services Docker)..."
DEVCONTAINER_ID="$(hostname)"
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:4873" 2>/dev/null || true
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:5000" 2>/dev/null || true
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:2222" 2>/dev/null || true
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:2223" 2>/dev/null || true
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:3001" 2>/dev/null || true
docker exec "$DEVCONTAINER_ID" pkill -f "socat TCP-LISTEN:3002" 2>/dev/null || true
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:4873,fork,reuseaddr TCP:verdaccio:4873
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:5000,fork,reuseaddr TCP:registry:5000
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:2222,fork,reuseaddr TCP:ssh-npm-target:22
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:2223,fork,reuseaddr TCP:ssh-docker-target:22
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:3001,fork,reuseaddr TCP:ssh-npm-target:3000
docker exec -d "$DEVCONTAINER_ID" socat TCP-LISTEN:3002,fork,reuseaddr TCP:ssh-docker-target:3000

if [ -f "$SSH_KEY_PATH.pub" ]; then
  echo "==> Injection de la clé publique dans les cibles SSH..."
  for target in tp-cd-deployment-ssh-npm-target tp-cd-deployment-ssh-docker-target; do
    docker exec "$target" sh -c "echo '$(cat "$SSH_KEY_PATH.pub")' > /home/deployer/.ssh/authorized_keys && chmod 600 /home/deployer/.ssh/authorized_keys && chown deployer:deployer /home/deployer/.ssh/authorized_keys"
  done
fi

echo "==> Attente du démarrage de Verdaccio..."
until curl -sf http://localhost:4873/-/ping > /dev/null 2>&1; do
  echo "   ... Verdaccio pas encore prêt, attente 2s..."
  sleep 2
done

echo "==> Attente du démarrage du registry Docker..."
until curl -sf http://localhost:5000/v2/ > /dev/null 2>&1; do
  echo "   ... registry:2 pas encore prêt, attente 2s..."
  sleep 2
done

echo "==> Attente des cibles SSH..."
for port in 2222 2223; do
  for i in $(seq 1 15); do
    if ssh -i "$SSH_KEY_PATH" -p "$port" -o StrictHostKeyChecking=no -o ConnectTimeout=3 deployer@localhost "echo ok" > /dev/null 2>&1; then
      echo "   SSH target $port opérationnelle"
      break
    fi
    echo "   ... SSH target $port pas encore prête ($i/15), attente 2s..."
    sleep 2
  done
done
