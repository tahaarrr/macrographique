# Macrographique — App Flutter (SQLite + PDF)

Application Android (Flutter) permettant de **créer, sauvegarder et générer en PDF**
des Rapports d'Essai (type ALTUMET / EPE ANABIB SPA), avec photos macro-graphiques
par échantillon, stockage local SQLite, et export PDF fidèle à la mise en page
du modèle papier.

## Fonctionnalités

- ✅ Formulaire complet (PV N°, dates, client, projet, dimensions, nuance, WPS/PQR,
  méthodes d'essai/échantillonnage, spécification…)
- ✅ Nombre d'échantillons **variable** (1 à N), chacun avec sa propre photo
- ✅ Photo par **appareil photo** ou **galerie**, au choix, pour chaque échantillon
- ✅ Sauvegarde locale en base **SQLite** (fonctionne hors-ligne)
- ✅ **Toutes les données sont modifiables** : chaque rapport peut être édité ou
  supprimé après création (bouton crayon / corbeille sur l'écran de détail)
- ✅ **Écran Paramètres** : logo, nom de société, adresse du laboratoire,
  référence/version du document, mentions de bas de page et texte de constat
  par défaut sont **personnalisables dans l'app**, sans toucher au code — le
  logo s'importe depuis la caméra ou la galerie et est réutilisé automatiquement
- ✅ Génération d'un **PDF** reproduisant la mise en page du modèle (en-tête
  dynamique avec logo, tableau d'infos, grille de photos "MACRO-GRAPHIQUE",
  tableau de signatures, mentions légales en bas de page)
- ✅ Aperçu / impression / partage du PDF (WhatsApp, email, etc.)
- ✅ N° de PV auto-incrémenté par année (ex: 07/2026)
- ✅ Liste des rapports avec recherche (client, PV, projet, nuance)

## Structure des fichiers fournis

```
rapport_essai_app/
├── pubspec.yaml
├── assets/
│   └── README_LOGO.txt        # note : logo géré dynamiquement dans l'app
├── android_manifest_patch/
│   └── AndroidManifest_permissions.xml   # permissions + nom d'app à ajouter
└── lib/
    ├── main.dart
    ├── models/
    │   ├── rapport.dart
    │   ├── echantillon.dart
    │   └── app_settings.dart      # identité société / logo / en-tête PDF
    ├── db/
    │   └── database_helper.dart
    ├── services/
    │   ├── pdf_service.dart       # génère le PDF à partir du rapport + AppSettings
    │   └── settings_service.dart  # persistance des paramètres (shared_preferences)
    └── screens/
        ├── home_screen.dart
        ├── rapport_form_screen.dart
        ├── rapport_detail_screen.dart
        └── settings_screen.dart   # écran de personnalisation (logo, en-tête…)
```

Ce zip ne contient **que le code source Dart** et les fichiers de config —
pas le squelette Android/iOS complet généré par `flutter create` (trop
volumineux et généré automatiquement). La procédure ci-dessous crée ce
squelette puis y injecte le code fourni.

## Installation (étape par étape)

### 1. Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installé (canal stable)
- Android Studio (ou juste les Android SDK/platform-tools) pour builder l'APK
- Un appareil Android ou un émulateur

Vérifiez votre installation :
```bash
flutter doctor
```

### 2. Créer le squelette du projet
```bash
flutter create rapport_essai_app
cd rapport_essai_app
```

### 3. Copier les fichiers fournis
Remplacez le `pubspec.yaml` généré par celui fourni, puis copiez le dossier
`lib/` fourni (il remplace entièrement le `lib/main.dart` par défaut) :

```bash
# depuis le dossier où vous avez décompressé ce zip
cp pubspec.yaml            /chemin/vers/rapport_essai_app/pubspec.yaml
cp -r lib/*                /chemin/vers/rapport_essai_app/lib/
mkdir -p /chemin/vers/rapport_essai_app/assets
cp assets/README_LOGO.txt  /chemin/vers/rapport_essai_app/assets/
# (optionnel) ajoutez votre propre logo.png dans assets/
```

### 4. Ajouter les permissions Android
Ouvrez `android/app/src/main/AndroidManifest.xml` dans le projet généré,
et collez le contenu de `android_manifest_patch/AndroidManifest_permissions.xml`
juste **avant** la balise `<application ...>`.

Vérifiez aussi que `minSdkVersion` est au moins `21` dans
`android/app/build.gradle` (requis par `sqflite`/`image_picker`) :
```gradle
defaultConfig {
    minSdkVersion 21
    ...
}
```

### 5. Installer les dépendances
```bash
flutter pub get
```

### 6. Lancer l'application
```bash
flutter run
```

### 7. Générer l'APK de production
```bash
flutter build apk --release
# APK généré dans : build/app/outputs/flutter-apk/app-release.apk
```

## Personnalisation dynamique (logo, en-tête, mentions)

Depuis l'écran d'accueil "Macrographique", appuyez sur l'icône ⚙️ (Paramètres)
pour configurer, **sans toucher au code** :

- le **logo** (photo prise sur place ou choisie dans la galerie)
- le nom de la société et de l'unité (ex: EPE ANABIB SPA / UNITE ALTUMET)
- le nom et l'adresse du laboratoire, le lieu d'exécution des essais
- la référence, la version et la date du document (ex: E10-P.LAB.02)
- le texte de constat pré-rempli pour les nouveaux rapports
- les deux mentions légales en bas de page

Ces valeurs sont stockées localement (via `shared_preferences`) et injectées
automatiquement dans **tous** les PDF générés par la suite — aucune donnée
n'est codée en dur dans l'application.

## Les données sont-elles modifiables ?

Oui, à deux niveaux :
1. **Chaque rapport** (client, dates, échantillons, photos…) peut être modifié
   ou supprimé à tout moment depuis son écran de détail.
2. **L'en-tête/l'identité de l'entreprise** (logo, adresses, mentions) est
   modifiable à tout moment depuis l'écran Paramètres, et s'applique à tous
   les rapports générés ensuite (les PDF déjà générés ne sont pas rétroactivement
   modifiés, mais peuvent être régénérés en rappuyant sur "Générer & Partager").

## Notes techniques

- **Base de données** : deux tables SQLite, `rapports` (1) et `echantillons` (N),
  liées par une clé étrangère `rapport_id` avec suppression en cascade.
- **Photos** : copiées dans le dossier applicatif (`getApplicationDocumentsDirectory()/photos`)
  pour rester disponibles même après suppression du fichier original (galerie/caméra).
- **PDF** : généré à la demande avec le package `pdf`, reproduisant fidèlement
  la structure du modèle (en-tête avec logo optionnel + référence document,
  tableau d'informations, grille de photos par 4, texte de constat, tableau
  de signatures, mentions légales). Le fichier est sauvegardé dans le
  dossier documents de l'app puis proposé à l'aperçu/partage via `printing`
  et `share_plus`.
- **Aucune donnée n'est envoyée sur internet** : tout est stocké et généré
  localement sur l'appareil.

## Prochaines améliorations possibles
- Export/sauvegarde de la base SQLite (backup/restauration)
- Signature manuscrite tactile dans le tableau de signatures
- Génération PDF multi-rapports groupés (comme le document source PV01–PV06)
- Thème sombre / personnalisation des couleurs de l'entreprise
