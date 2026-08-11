# CreateVideo - Projet macOS

Application macOS permettant de générer automatiquement des arborescences de projets vidéo, avec des modèles configurables.

## Lancer l'application en développement

Le projet utilise Swift Package Manager. Vous pouvez le lancer via la commande :

```bash
./build_and_run.sh
```

## Créer une Release (Mise à jour & DMG)

Le projet intègre un système de mise à jour automatique. Pour diffuser une nouvelle version :

1. Assurez-vous d'avoir commité vos derniers changements.
2. Exécutez le script de release en spécifiant la version souhaitée :
   ```bash
   ./release.sh 1.0.1
   ```
3. Cela va compiler l'application en mode `release` et générer un fichier d'installation `BackupVideo-v1.0.1.dmg`.
4. Allez sur votre dépôt GitHub (`ArnaudGct/BackupVideo`) -> **Releases** -> **Draft a new release**.
5. Créez un tag correspondant à la version (ex: `v1.0.1` ou `1.0.1`).
6. Uploadez le fichier `.dmg` généré dans les assets de la release.
7. Remplissez les notes de version et publiez la release.
8. Les utilisateurs actuels recevront une notification au prochain lancement de l'application !
