# Cache `node_modules`

Chaque job GitHub Actions s'execute dans un environnement jetable. Le dossier `node_modules` installe dans `install` n'est donc pas disponible naturellement dans `format-lint`, `tests`, `build` ou les jobs de publication.

Le workflow restaure un cache avec cette cle :

```yaml
key: node-modules-${{ hashFiles('package-lock.json') }}
```

Tant que `package-lock.json` ne change pas, la cle reste la meme et les jobs peuvent restaurer rapidement le meme dossier `node_modules`.

## Dans `act`

Avec `act`, les jobs tournent dans des conteneurs Docker locaux. Le fichier `.actrc` ajoute un volume npm dedie :

```text
--container-options=--volume=tp-cd-deployment-act-npm:/root/.npm
```

Ce volume evite de retélécharger inutilement les packages entre plusieurs executions locales.

## Cache et artefacts

Le cache sert aux dependances. Il ne doit pas etre confondu avec l'artefact `build-dist`.

| Mecanisme | Sert a |
|---|---|
| Cache `node_modules` | Reutiliser les dependances entre jobs. |
| Artefact `build-dist` | Transmettre le resultat compile aux jobs de publication. |
