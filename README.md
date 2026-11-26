# Adjamé-Smart — app mobile

Flutter (Android et iOS). Une seule app : espace client (catégories, boutiques) et espace vendeur (inscription de la boutique).

```bash
flutter pub get
flutter run --dart-define=API_URL=http://<IP du Mac>:3100   # API locale
flutter build apk --release                                  # production : https://api.as.performx.online
```

Phase 1 : connexion / création de compte, découverte (catégories, boutiques en ligne, page boutique), compte (adresses, statut revendeur), ouverture d'une boutique (infos, catégories, emplacement sur la carte d'Adjamé, horaires, photos, pièce du gérant, envoi du dossier à l'équipe).

Thème par défaut : vert #0F8A5F (`lib/theme.dart`), à remplacer par l'identité visuelle définitive.
