import 'package:url_launcher/url_launcher.dart';

/// Liens d'un texte riche : seuls http(s), mailto et tel sont acceptés à la
/// saisie et ouverts à la lecture (repris d'AEECI, `RichTextLinkService`).
///
/// Le serveur filtre déjà les liens à l'enregistrement ; ce second contrôle
/// protège aussi un contenu ancien ou mis en cache.
abstract final class RichTextLinks {
  static Uri? parse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    return switch (uri.scheme.toLowerCase()) {
      'http' || 'https' when uri.host.isNotEmpty => uri,
      'mailto' when uri.path.isNotEmpty => uri,
      'tel' when uri.path.isNotEmpty => uri,
      _ => null,
    };
  }

  /// Ouvre le lien dans l'application adaptée (navigateur, e-mail,
  /// téléphone). Un lien refusé ne fait rien et renvoie `false`.
  static Future<bool> open(String? value) async {
    final uri = parse(value);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
