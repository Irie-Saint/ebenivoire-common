import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable per-device identity (id / model / type), resolved once and cached.
///
/// Used to tag the login session so the user can see and revoke this device in
/// "Mes appareils". All fields are optional on the backend: a failure to
/// resolve simply means the session is tagged with less detail.
///
/// Sur le web, l'identifiant est rangé sous [webStorageKey]. L'app cliente et
/// la console le partagent avec l'inscription aux notifications ; l'app
/// vendeur a toujours eu sa propre clé et la garde (`configure` au démarrage) :
/// changer de clé ferait de chaque navigateur un « nouvel appareil ».
class DeviceIdentity {
  static Map<String, String?>? _cached;

  static String webStorageKey = 'ev_web_push_device_id';

  /// À appeler au démarrage, avant la première connexion.
  static void configure({String? webStorageKey}) {
    if (webStorageKey != null && webStorageKey.isNotEmpty) {
      DeviceIdentity.webStorageKey = webStorageKey;
    }
  }

  static Future<Map<String, String?>> resolve() async {
    if (_cached != null) return _cached!;

    String? deviceId;
    String? model;
    String? type;

    try {
      if (kIsWeb) {
        _cached = {'deviceId': await _webId(), 'model': 'Web', 'type': 'web'};
        return _cached!;
      }

      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        type = 'android';
        final a = await info.androidInfo;
        model = '${a.manufacturer} ${a.model}';
        deviceId = a.id;
      } else if (Platform.isIOS) {
        type = 'ios';
        final i = await info.iosInfo;
        model = i.utsname.machine;
        deviceId = i.identifierForVendor;
      } else {
        type = 'other';
        model = Platform.operatingSystem;
      }
    } catch (e) {
      debugPrint('DeviceIdentity: failed to resolve: $e');
    }

    _cached = {'deviceId': deviceId, 'model': model, 'type': type};
    return _cached!;
  }

  /// `X-Device-*` headers for the login request (empty values omitted). The
  /// backend treats them as optional, so a failure to resolve just means the
  /// session is tagged with less detail.
  static Future<Map<String, String>> headers() async {
    try {
      final d = await resolve();
      final h = <String, String>{};
      final id = d['deviceId'];
      final model = d['model'];
      final type = d['type'];
      if (id != null && id.isNotEmpty) h['X-Device-Id'] = id;
      if (model != null && model.isNotEmpty) h['X-Device-Model'] = model;
      if (type != null && type.isNotEmpty) h['X-Device-Type'] = type;
      return h;
    } catch (_) {
      return const {};
    }
  }

  static Future<String> _webId() async {
    final prefs = await SharedPreferences.getInstance();
    final key = webStorageKey;
    var id = prefs.getString(key);
    if (id == null || id.isEmpty) {
      final rnd = Random();
      id =
          'web-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-'
          '${rnd.nextInt(0x7fffffff).toRadixString(16)}';
      await prefs.setString(key, id);
    }
    return id;
  }
}
