import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thème de l'app : système (suit le téléphone), clair ou sombre.
///
/// Jusqu'ici `GetMaterialApp` forçait `ThemeMode.light` : le thème sombre
/// existait dans tout le code (`isDark` partout) sans aucun moyen d'y arriver.
/// Le choix est lu AVANT le premier cadre (pas de flash clair au démarrage) et
/// persiste dans les préférences.
class ThemeModeService extends GetxService {
  static const storageKey = 'app_theme_mode';

  final SharedPreferences _prefs;
  final Rx<ThemeMode> mode;

  ThemeModeService(this._prefs) : mode = restore(_prefs).obs;

  /// Valeur enregistrée, `system` par défaut ou si la valeur est inconnue.
  static ThemeMode restore(SharedPreferences prefs) =>
      parse(prefs.getString(storageKey));

  static ThemeMode parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setMode(ThemeMode next) async {
    if (mode.value == next) return;
    mode.value = next;
    Get.changeThemeMode(next);
    await _prefs.setString(storageKey, next.name);
  }
}
