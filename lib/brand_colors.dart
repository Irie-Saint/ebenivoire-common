import 'package:flutter/material.dart';

/// Couleurs de la marque partagées par les trois apps (mêmes valeurs dans
/// chaque `AppColors`), pour les éléments du paquet qui s'affichent :
/// squelettes de chargement, indicateurs, feuille d'avis.
///
/// ⚠️ Si une valeur change dans le thème d'une app, la changer ICI aussi —
/// ou mieux, faire pointer `AppColors` de l'app vers cette classe.
abstract final class BrandColors {
  static const Color brandPrimary = Color(0xFF3E5A99);

  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2E);
  static const Color divider = Color(0xFFE5E7EB);

  static const Color lightSecondaryText = Color(0xFF6B7280);
  static const Color darkSecondaryText = Color(0xFFAAAAAA);

  static const MaterialColor warningColor = Colors.amber;

  // Squelettes de chargement (fond → reflet), selon le thème clair/sombre.
  static const Color skeletonBaseLight = Color(0xFFE4E7EB);
  static const Color skeletonHighlightLight = Color(0xFFF3F5F7);
  static const Color skeletonBaseDark = Color(0xFF2C2C2E);
  static const Color skeletonHighlightDark = Color(0xFF3A3A3C);
}
