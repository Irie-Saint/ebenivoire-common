/// Conditions de la plateforme (CGU, politique de confidentialité) et
/// l'acceptation de l'utilisateur. Même forme pour la cliente
/// (`/api/profile/me/terms`) et le vendeur (`/vendors/me/terms`).
class PlatformTerms {
  final String title;
  final String content; // HTML
  final String version;
  final bool accepted;
  final String? acceptedVersion;
  final DateTime? acceptedAt;

  const PlatformTerms({
    required this.title,
    required this.content,
    required this.version,
    required this.accepted,
    this.acceptedVersion,
    this.acceptedAt,
  });

  /// L'utilisateur avait accepté une version antérieure : c'est une mise à jour,
  /// pas une première acceptation.
  bool get isUpdate =>
      !accepted &&
      (acceptedVersion ?? '').isNotEmpty &&
      acceptedVersion != version;

  factory PlatformTerms.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    return PlatformTerms(
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      version: data['version']?.toString() ?? '',
      accepted: data['accepted'] == true,
      acceptedVersion: data['accepted_version']?.toString(),
      acceptedAt: _utc(data['accepted_at']),
    );
  }

  /// Le serveur écrit ses dates en UTC sans fuseau : sans le `Z`, Dart les
  /// lirait comme heure locale.
  static DateTime? _utc(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return null;
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(text);
    return DateTime.tryParse(hasZone ? text : '${text}Z')?.toLocal();
  }
}

/// Échec d'une opération sur les conditions, avec le code du serveur quand il
/// en donne un (`TERMS_VERSION_CHANGED`).
class TermsException implements Exception {
  final String? errorCode;

  const TermsException([this.errorCode]);

  bool get versionChanged => errorCode == 'TERMS_VERSION_CHANGED';
}
