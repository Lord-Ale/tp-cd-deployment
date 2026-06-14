# Pipeline CI/CD du TP

Le workflow `.github/workflows/ci.yml` est volontairement deja complet jusqu'a
la publication des artefacts.

```text
install -> format-lint -> tests -> tests-e2e -> build -> security
security -> release -> publish-npm
                    -> publish-docker
```

Votre travail consiste a ajouter la suite Continuous Deployment :

```text
publish-npm    -> deploy-npm    ┐
publish-docker -> deploy-docker ├-> healthcheck-deployment
                                └-> rollback si echec
```

Le TP suit un Trunk-Based Workflow : les changements restent petits, integres
frequemment sur `main`, puis verifies par la pipeline.

## Jobs initiaux

| Job | Role |
|---|---|
| `install` | Installe les dependances avec `npm ci` et prepare le cache `node_modules`. |
| `format-lint` | Verifie Prettier et ESLint/SonarJS. |
| `tests` | Lance les tests unitaires avec couverture. |
| `tests-e2e` | Lance les tests HTTP avec Supertest sur l'application NestJS en memoire. |
| `build` | Compile TypeScript vers `dist/` et sauvegarde l'artefact `build-dist`. |
| `security` | Lance Trivy sur le depot. Le scan informe mais ne bloque pas la pipeline. |
| `release` | Calcule la version SemVer et prepare le tag. |
| `publish-npm` | Publie le package dans Verdaccio. |
| `publish-docker` | Publie l'image dans `registry:2`. |

## Pourquoi sauvegarder `build-dist` ?

Les jobs GitHub Actions sont isoles. Le dossier `dist/` produit par `build` n'existe donc pas automatiquement dans `publish-npm` ou `publish-docker`.

Le workflow utilise :

- `actions/upload-artifact@v4` dans `build` ;
- `actions/download-artifact@v4` dans les jobs de publication.

Cela illustre le principe `build once, publish many` : le meme build sert au package npm et a l'image Docker.

## Conditions de branche

Les jobs de publication et de deploiement doivent etre limites a `main` :

```yaml
if: github.ref == 'refs/heads/main'
```

Une branche de travail doit donc valider la CI, mais ne doit pas publier ni
deployer d'artefact.

## `act` et release locale

Quand `act` lance le job `release`, `npx commit-and-tag-version` modifie le
clone Git present dans le runner ephemere. Le commit de release et le tag ne
sont pas recopies dans votre depot local.

Avant de coder une nouvelle modification apres un essai de release, lancez donc
la commande localement :

```bash
npx commit-and-tag-version
```

Vous repartez ainsi d'un `main` local aligne avec le bump de version et le
changelog attendus.
