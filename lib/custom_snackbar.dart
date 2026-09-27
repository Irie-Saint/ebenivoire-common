import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Messages courts en haut de l'écran (succès, erreur, alerte, info), pour le
/// vendeur et la console.
///
/// Les couleurs viennent du thème de l'app : chaque app appelle [configure]
/// au démarrage avec ses `AppColors`. Les valeurs par défaut sont celles du
/// thème actuel des deux apps, pour qu'un oubli ne change rien à l'écran.
class CustomSnackbar {
  CustomSnackbar._();

  static Color _success = const Color(0xFF28A745);
  static Color _warning = Colors.amber;
  static Color _info = Colors.blue;

  /// Couleurs du thème de l'app (l'erreur suit `colorScheme.error`).
  static void configure({
    required Color success,
    required Color warning,
    required Color info,
  }) {
    _success = success;
    _warning = warning;
    _info = info;
  }

  static bool _canShowSnackbar() {
    if (Get.overlayContext == null) {
      debugPrint('⚠️ Overlay context not available, cannot show snackbar');
      return false;
    }
    return true;
  }

  static void _show({
    required String title,
    required String message,
    required Color background,
    Icon? icon,
  }) {
    if (!_canShowSnackbar()) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: background,
      colorText: Colors.white,
      margin: EdgeInsets.all(16.w),
      duration: const Duration(seconds: 3),
      borderRadius: 8,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      icon: icon,
    );
  }

  static void success({required String title, required String message}) =>
      _show(
        title: title,
        message: message,
        background: _success,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );

  static void error({required String title, required String message}) {
    if (!_canShowSnackbar()) return;
    _show(
      title: title,
      message: message,
      background: Get.theme.colorScheme.error,
    );
  }

  static void warning({required String title, required String message}) =>
      _show(
        title: title,
        message: message,
        background: _warning,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      );

  static void info({required String title, required String message}) => _show(
    title: title,
    message: message,
    background: _info,
    icon: const Icon(Icons.info_outline, color: Colors.white),
  );
}
