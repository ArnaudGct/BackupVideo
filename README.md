# BackupVideo - Instructions d'installation

Ce dossier contient tout le code source nécessaire pour générer l'application native macOS **BackupVideo**. L'architecture respecte les patterns SwiftUI et Swift Concurrency (asynchronisme natif), ainsi que les bonnes pratiques App Sandbox de macOS pour l'accès aux dossiers (Bookmarks).

## Étape 1 : Créer un projet Xcode

1. Ouvrez **Xcode**.
2. Cliquez sur **Create a new Xcode project**.
3. Choisissez l'onglet **macOS** et sélectionnez **App**. Cliquez sur Next.
4. Entrez les informations suivantes :
   - **Product Name** : `BackupVideo`
   - **Interface** : SwiftUI
   - **Language** : Swift
5. Cliquez sur Next et choisissez un dossier (pas celui-ci, mais un dossier vide pour générer le projet Xcode).

## Étape 2 : Intégrer les fichiers sources

1. Dans Xcode, supprimez les fichiers générés par défaut `ContentView.swift` et `BackupVideoApp.swift` (Déplacez-les vers la corbeille).
2. Prenez tous les dossiers et fichiers présents dans CE dossier (Models, Services, ViewModels, Views, BackupVideoApp.swift) et glissez-les/déposez-les dans le navigateur de projet Xcode (panneau de gauche).
3. Dans la popup qui s'ouvre, cochez **"Copy items if needed"** et assurez-vous que votre target ("BackupVideo") est bien cochée sous "Add to targets".

## Étape 3 : Configurer l'App Sandbox (CRITIQUE)

Pour que l'application puisse lire et écrire dans vos dossiers, il faut configurer le Sandbox macOS.

1. Cliquez sur le nom de votre projet en haut à gauche (l'icône bleue).
2. Sélectionnez votre target "BackupVideo".
3. Allez dans l'onglet **Signing & Capabilities**.
4. Dans la section **App Sandbox**, cherchez **File Access**.
5. Changez "User Selected File" de _None_ à **Read/Write**.

## Étape 4 : Compiler et lancer

1. Sélectionnez "My Mac" comme destination de build en haut.
2. Appuyez sur `Cmd + R` (ou le bouton Play) pour lancer l'application.

L'application est prête à sécuriser vos workflows !
