/// Textes du noyau de connexion (session, serveur injoignable) — mêmes clés
/// dans les trois apps.
const Map<String, Map<String, String>> sessionMessages = {
  'en_US': {
    'core_session.unreachable':
        'Server unreachable. Your session is kept, please try again.',
    'core_session.refresh_failed':
        'Your connection could not be renewed. Please try again.',
    'core_session.unreachable_title': 'Server unreachable',
    'core_session.unreachable_message':
        'Check your connection. This page will reload by itself as soon '
        'as the server answers again.',
  },
  'fr': {
    'core_session.unreachable':
        'Serveur injoignable. Votre session est conservée, réessayez.',
    'core_session.refresh_failed':
        'Votre connexion n’a pas pu être renouvelée. Réessayez.',
    'core_session.unreachable_title': 'Serveur injoignable',
    'core_session.unreachable_message':
        'Vérifiez votre connexion. La page se rechargera toute seule dès que '
        'le serveur répondra à nouveau.',
  },
};
