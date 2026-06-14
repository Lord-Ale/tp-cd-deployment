#!/bin/bash
set -ex

WORKSPACE="/workspaces/tp-cd-deployment"
SSH_KEY_PATH="$HOME/.ssh/tp_cd_deployment_key"

echo "==> Installation des dépendances npm..."
npm ci

echo "==> Création de la base de données SQLite et initialisation des données de démonstration..."
DATABASE_URL="./dev.db" npx ts-node db/seed.ts

echo "==> Génération de la paire de clés SSH pour les déploiements..."
mkdir -p "$HOME/.ssh"
rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "tp-cd-deployment"

echo "==> Création du fichier de secrets pour act..."
{ printf 'SSH_PRIVATE_KEY="'; cat "$SSH_KEY_PATH"; printf '"'; } > "$WORKSPACE/.secrets"
chmod 600 "$WORKSPACE/.secrets"

echo "==> Configuration SSH locale..."
cat >> "$HOME/.ssh/config" <<EOF

Host tp-cd-deployment-npm
  HostName localhost
  Port 2222
  User deployer
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  IdentityFile $SSH_KEY_PATH

Host tp-cd-deployment-docker
  HostName localhost
  Port 2223
  User deployer
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  IdentityFile $SSH_KEY_PATH
EOF
chmod 600 "$HOME/.ssh/config"

bash .devcontainer/start-services.sh

echo "==> Installation de act (exécution locale des GitHub Actions)..."
# 1. On télécharge le script d'installation officiel
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh -o install_act.sh

# 2. On l'exécute explicitement en forçant le dossier système de destination
sudo bash install_act.sh -b /usr/local/bin/

# 3. On nettoie le script temporaire
rm install_act.sh

# 4. On s'assure que le binaire est exécutable par tout le monde
sudo chmod +x /usr/local/bin/act

echo "==> Pré-téléchargement de l'image Docker pour act..."
docker pull catthehacker/ubuntu:act-24.04

echo "==> Installation de Trivy (scan de sécurité)..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

echo ""
echo "✅ Environnement prêt !"
echo "   - Application : npm run start:dev  →  http://localhost:3000"
echo "   - Swagger      : http://localhost:3000/api"
echo "   - Tests        : npm test"
echo "   - CI locale    : act"
echo "   - Verdaccio    : http://localhost:4873"
echo "   - Registry     : http://localhost:5000/v2/"
echo "   - SSH npm      : ssh tp-cd-deployment-npm"
echo "   - SSH Docker   : ssh tp-cd-deployment-docker"
echo "   - App npm      : http://localhost:3001 après déploiement"
echo "   - App Docker   : http://localhost:3002 après déploiement"
