# tp-cd-deployment

API de gestion de taches - support du TP cours-04 sur le Continuous Deployment.

## Objectifs pedagogiques

Ce depot part d'une pipeline de Continuous Delivery deja en place. Vous ajoutez
la derniere etape :

- deployer automatiquement un package npm publie dans Verdaccio ;
- deployer automatiquement une image Docker publiee dans `registry:2` ;
- verifier les deux deploiements avec un healthcheck final ;
- livrer une fonctionnalite simple derriere un feature flag ;
- ajouter un rollback automatique pedagogique.

Le TP illustre un Trunk-Based Workflow : petits changements, `main` toujours
vert, publication et deploiement automatises.

## Stack technique

| Outil | Role |
|---|---|
| Node 24 + NestJS 11 | API backend |
| better-sqlite3 | Base SQLite locale |
| Jest + Supertest | Tests unitaires et E2E |
| Prettier + ESLint | Qualite de code |
| Trivy | Scan de vulnerabilites |
| commit-and-tag-version | Versioning SemVer depuis les commits |
| Verdaccio | Registre npm local |
| registry:2 | Registre Docker local |
| SSH + pm2 | Deploiement du package npm |
| SSH + Docker | Deploiement de l'image Docker |
| act | Execution locale des workflows GitHub Actions |

## Demarrage recommande

Prerequis : Docker Desktop, VS Code et l'extension Dev Containers.

1. Forker le depot `GVI2026/tp-cd-deployment` sur GitHub.
2. Cloner votre fork :
   ```bash
   git clone <url-de-votre-fork>
   cd tp-cd-deployment
   ```
3. Ouvrir le dossier dans VS Code.
4. Accepter `Reopen in Container`.
5. Attendre la fin du `postCreateCommand`.

Le DevContainer installe les dependances, initialise SQLite, genere une cle SSH,
demarre Verdaccio, `registry:2`, les deux cibles SSH, installe `act` et prepare
le fichier `.secrets` utilise par `act`.

## Services locaux

| Service | URL ou commande |
|---|---|
| API locale | http://localhost:3000 |
| Swagger | http://localhost:3000/api |
| Verdaccio | http://localhost:4873 |
| Docker Registry | http://localhost:5000/v2/ |
| SSH npm target | `ssh tp-cd-deployment-npm` |
| SSH Docker target | `ssh tp-cd-deployment-docker` |
| App npm deployee | http://localhost:3001 |
| App Docker deployee | http://localhost:3002 |

Commandes de verification :

```bash
curl http://localhost:4873/-/ping
curl http://localhost:5000/v2/
ssh tp-cd-deployment-npm "echo ok"
ssh tp-cd-deployment-docker "echo ok"
```

Si les relais reseau tombent apres une veille :

```bash
bash bin/check-relays.sh
```

## Tests et CI locale

```bash
npm test
npm run test:e2e
act -j security
```

Pipeline fournie :

```text
install -> format-lint -> tests -> tests-e2e -> build -> security
security -> release -> publish-npm
                    -> publish-docker
```

Mission du TP :

```text
publish-npm    -> deploy-npm    ┐
publish-docker -> deploy-docker ├-> healthcheck-deployment
                                └-> rollback si echec
```

## Exercices

Les consignes detaillees sont dans [EXERCICE.md](./EXERCICE.md).

Commandes utiles :

```bash
act -j publish-npm
npm view tp-cd-deployment --registry http://localhost:4873
act -j publish-docker
curl http://localhost:5000/v2/tp-cd-deployment/tags/list
act -j healthcheck-deployment
curl http://localhost:3001/health
curl http://localhost:3002/health
```

## Nettoyer l'environnement local

```bash
docker compose down
docker volume rm tp-cd-deployment_verdaccio-storage 2>/dev/null || true
docker volume rm tp-cd-deployment_registry-storage 2>/dev/null || true
bash .devcontainer/start-services.sh
```

## Documentation utile

- [docs/ci-pipeline.md](docs/ci-pipeline.md) : rappel de la CI et de la Delivery fournie.
- [docs/fonctionnement-cache.md](docs/fonctionnement-cache.md) : cache `node_modules`.
- [docs/artefacts-et-runners.md](docs/artefacts-et-runners.md) : passage du build aux publications.
