# Exercices - TP Cours-04 : Continuous Deployment

## Contexte

La pipeline de Continuous Delivery est deja en place :

```text
install -> format-lint -> tests -> tests-e2e -> build -> security
security -> release -> publish-npm
                    -> publish-docker
```

Votre mission est d'ajouter la derniere etape : deployer automatiquement les
deux artefacts publies, puis verifier que les services deployes repondent.

Le TP suit un Trunk-Based Workflow : petits changements sur `main`, pipeline
verte, publication, deploiement automatique.

Infrastructure disponible dans le DevContainer :

- API locale : `http://localhost:3000`
- Verdaccio : `http://localhost:4873`
- Docker Registry : `http://localhost:5000`
- Cible SSH npm : `tp-cd-deployment-npm`, application exposee sur `3001`
- Cible SSH Docker : `tp-cd-deployment-docker`, application exposee sur `3002`
- Execution locale GitHub Actions : `act`

Avant de commencer :

```bash
curl http://localhost:4873/-/ping
curl http://localhost:5000/v2/
ssh tp-cd-deployment-npm "echo ok"
ssh tp-cd-deployment-docker "echo ok"
act -j publish-npm
act -j publish-docker
```

Si un relais reseau ne repond plus apres une veille du poste :

```bash
bash bin/check-relays.sh
```

## Preparation du depot

Comme pour les TP precedents, commencez par travailler depuis votre fork :

```bash
git clone <url-de-votre-fork>
cd tp-cd-deployment
```

Le TP reste local : `act` execute les jobs, Verdaccio stocke le package npm,
`registry:2` stocke l'image Docker, et deux environnements Docker distincts
simulent les serveurs de deploiement accessibles en SSH.

## Exercice 1 - Ajouter le Continuous Deployment

Objectif : deployer automatiquement les deux artefacts produits par la Delivery.

Ajoutez trois jobs dans `.github/workflows/ci.yml`.

### Job `deploy-npm`

- `needs: [publish-npm]`
- limite a `main`
- calcule la version depuis `package.json`
- se connecte a `deployer@localhost:2222`
- installe `tp-cd-deployment@<version>` depuis Verdaccio
- redemarre l'application avec pm2 sur le port `3000` de la cible

Solution :

```yaml
deploy-npm:
  name: Deploy npm
  runs-on: ubuntu-latest
  needs: [publish-npm]
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4

    - name: Calculer la version
      id: version
      run: |
        VERSION=$(node -p "require('./package.json').version")
        echo "version=${VERSION}" >> "$GITHUB_OUTPUT"

    - name: Deployer le package npm
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: localhost
        port: 2222
        username: deployer
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          set -e
          mkdir -p ~/app
          CURRENT=$(node -p "require('/home/deployer/app/node_modules/tp-cd-deployment/package.json').version" 2>/dev/null || echo "")
          echo "$CURRENT" > ~/app/.previous-npm-version
          npm install --prefix ~/app tp-cd-deployment@${{ steps.version.outputs.version }} --registry http://verdaccio:4873 --ignore-scripts
          pm2 delete tp-cd-deployment-npm 2>/dev/null || true
          PORT=3000 DATABASE_URL=/home/deployer/app/dev.db pm2 start ~/app/node_modules/tp-cd-deployment/dist/src/main.js --name tp-cd-deployment-npm --update-env
```

### Job `deploy-docker`

- `needs: [publish-docker]`
- limite a `main`
- calcule la version depuis `package.json`
- se connecte a `deployer@localhost:2223`
- pull l'image publiee
- relance un conteneur applicatif expose sur `3002`

Solution :

```yaml
deploy-docker:
  name: Deploy Docker
  runs-on: ubuntu-latest
  needs: [publish-docker]
  if: github.ref == 'refs/heads/main'

  steps:
    - uses: actions/checkout@v4

    - name: Calculer la version
      id: version
      run: |
        VERSION=$(node -p "require('./package.json').version")
        echo "version=${VERSION}" >> "$GITHUB_OUTPUT"

    - name: Deployer l'image Docker
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: localhost
        port: 2223
        username: deployer
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          set -e
          docker pull localhost:5000/tp-cd-deployment:${{ steps.version.outputs.version }}
          docker rm -f tp-cd-deployment-app 2>/dev/null || true
          docker run -d \
            --name tp-cd-deployment-app \
            --network container:tp-cd-deployment-ssh-docker-target \
            -e PORT=3000 \
            -e DATABASE_URL=/app/dev.db \
            localhost:5000/tp-cd-deployment:${{ steps.version.outputs.version }}
```

### Job `healthcheck-deployment`

- `needs: [deploy-npm, deploy-docker]`
- limite a `main`
- verifie les deux services deployes

Solution :

```yaml
healthcheck-deployment:
  name: Healthcheck deployment
  runs-on: ubuntu-latest
  needs: [deploy-npm, deploy-docker]
  if: github.ref == 'refs/heads/main'

  steps:
    - name: Verifier le service npm
      run: curl -f http://localhost:3001/health

    - name: Verifier le service Docker
      run: curl -f http://localhost:3002/health
```

Verification :

```bash
act -j healthcheck-deployment
curl http://localhost:3001/health
curl http://localhost:3002/health
```

## Exercice 2 - Ajouter une fonctionnalite avec feature flag

Objectif : deployer un code nouveau sans rendre immediatement la fonctionnalite
visible.

Ajoutez un endpoint `GET /tasks/summary` qui retourne un resume simple :

```json
{
  "total": 3,
  "done": 1,
  "open": 2
}
```

Le feature flag est volontairement en dur dans le code pour ce premier TP :

```ts
const ENABLE_TASK_SUMMARY = false;
```

Travail attendu :

1. Ajouter une methode `summary()` dans `TasksService`.
2. Ajouter `GET /tasks/summary` dans `TasksController`.
3. Si `ENABLE_TASK_SUMMARY` vaut `false`, retourner une erreur 404 ou 403.
4. Ajouter un test unitaire ou E2E qui prouve que la route est protegee.
5. Committer le code avec le flag a `false` :
   ```bash
   git add src test
   git commit -m "feat: add flagged task summary"
   ```
6. Activer ensuite le flag a `true` dans un second petit commit :
   ```bash
   git add src/tasks/tasks.controller.ts
   git commit -m "feat: enable task summary"
   ```

Ce decoupage illustre le Trunk-Based Workflow : le code peut etre integre et
deployee rapidement, sans exposer tout de suite la fonctionnalite.

Verification :

```bash
npm test
npm run test:e2e
act -j healthcheck-deployment
curl http://localhost:3001/tasks/summary
curl http://localhost:3002/tasks/summary
```

## Exercice 3 - Rollback automatique simple

Objectif : si le healthcheck final echoue, revenir automatiquement a la derniere
version connue.

Approche recommandee :

- avant le deploiement npm, lire la version actuellement installee et l'ecrire
  dans `~/app/.previous-npm-version` ;
- avant le deploiement Docker, conserver l'image courante dans un tag local
  `tp-cd-deployment:previous` si le conteneur existe ;
- ajouter des steps de rollback conditionnels avec `if: failure()`.

### Rollback npm

Ajoutez avant l'installation :

```bash
CURRENT=$(node -p "require('/home/deployer/app/node_modules/tp-cd-deployment/package.json').version" 2>/dev/null || echo "")
echo "$CURRENT" > ~/app/.previous-npm-version
```

Puis ajoutez un step apres le healthcheck :

```yaml
- name: Rollback npm si le healthcheck echoue
  if: failure()
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: localhost
    port: 2222
    username: deployer
    key: ${{ secrets.SSH_PRIVATE_KEY }}
    script: |
      PREVIOUS=$(cat ~/app/.previous-npm-version 2>/dev/null || echo "")
      if [ -z "$PREVIOUS" ]; then
        echo "Aucune version npm precedente connue."
        exit 1
      fi
      npm install --prefix ~/app tp-cd-deployment@${PREVIOUS} --registry http://verdaccio:4873 --ignore-scripts
      pm2 restart tp-cd-deployment-npm --update-env
```

### Rollback Docker

Avant de remplacer le conteneur :

```bash
if docker inspect tp-cd-deployment-app >/dev/null 2>&1; then
  CURRENT_IMAGE=$(docker inspect -f '{{.Config.Image}}' tp-cd-deployment-app)
  docker tag "$CURRENT_IMAGE" tp-cd-deployment:previous
fi
```

Puis ajoutez un step de rollback :

```yaml
- name: Rollback Docker si le healthcheck echoue
  if: failure()
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: localhost
    port: 2223
    username: deployer
    key: ${{ secrets.SSH_PRIVATE_KEY }}
    script: |
      docker image inspect tp-cd-deployment:previous >/dev/null
      docker rm -f tp-cd-deployment-app 2>/dev/null || true
      docker run -d --name tp-cd-deployment-app --network container:tp-cd-deployment-ssh-docker-target tp-cd-deployment:previous
```

Limites de la simulation :

- il faut au moins une version precedente pour pouvoir revenir en arriere ;
- le registre local doit conserver cette version ;
- dans une vraie plateforme, le rollback s'appuie aussi sur des runbooks, des
  traces d'audit et des alertes.

## Nettoyage

```bash
docker compose down
docker volume rm tp-cd-deployment_verdaccio-storage 2>/dev/null || true
docker volume rm tp-cd-deployment_registry-storage 2>/dev/null || true
bash .devcontainer/start-services.sh
```
