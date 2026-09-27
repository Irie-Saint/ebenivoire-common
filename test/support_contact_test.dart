import 'package:ebenivoire_common/support_contact.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contact support : un seul exemplaire pour la cliente et le vendeur.
///
/// ⚠️ Le vendeur avait une autre adresse de secours (support@asameb.com) ;
/// décision du 27/09 : support@ebenivoire.com partout. Le serveur la remplace
/// dès qu'il répond.
void main() {
  test('adresse de secours : support@ebenivoire.com', () {
    expect(kSupportEmailFallback, 'support@ebenivoire.com');
  });

  test('les valeurs du serveur remplacent celles de secours', () {
    hydrateSupportContact({
      'email': 'aide@ebenivoire.com',
      'response_time_hours': 12,
    });
    expect(supportEmail, 'aide@ebenivoire.com');
    expect(supportResponseHours, 12);
    expect(supportMailtoUri, 'mailto:aide@ebenivoire.com');
  });
}
