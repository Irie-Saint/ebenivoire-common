/// Single source for the customer-support contact channels.
///
/// Values are hydrated from the backend (`GET /api/app/config` →
/// `support_contact`, admin-editable) via [hydrateSupportContact], exactly like
/// the currency symbol. The `k*Fallback` constants are used ONLY until that
/// fetch lands (or if it fails / a field is missing), so the channels always
/// work offline.
library;

/// Fallback support number (digits only, E.164 without '+').
const String kSupportPhoneDigits = '2250505050505';
const String kSupportEmailFallback = 'support@ebenivoire.com';
const String kSupportHoursFallback = 'Lun - Dim : 8h - 16h';
const int kSupportResponseHoursFallback = 24;

// Backend-hydrated values (null until /api/app/config lands).
String? _phoneDigits;
String? _whatsappDigits;
String? _email;
String? _hours;
int? _responseHours;

String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

/// Hydrate from the backend `support_contact` payload (from /api/app/config).
/// Only non-empty fields overwrite the current values, so a partially-filled
/// admin value never blanks a channel.
void hydrateSupportContact(Map<String, dynamic> json) {
  final phone = json['phone']?.toString().trim();
  if (phone != null && phone.isNotEmpty) _phoneDigits = _digitsOnly(phone);

  final whatsapp = json['whatsapp']?.toString().trim();
  if (whatsapp != null && whatsapp.isNotEmpty) {
    _whatsappDigits = _digitsOnly(whatsapp);
  }

  final email = json['email']?.toString().trim();
  if (email != null && email.isNotEmpty) _email = email;

  final hours = json['hours']?.toString().trim();
  if (hours != null && hours.isNotEmpty) _hours = hours;

  final responseTime = json['response_time_hours'];
  if (responseTime is num) _responseHours = responseTime.toInt();
}

/// Support call/WhatsApp number, digits only (backend value, else fallback).
String get supportPhoneDigits => _phoneDigits ?? kSupportPhoneDigits;
String get _supportWhatsAppDigits =>
    _whatsappDigits ?? _phoneDigits ?? kSupportPhoneDigits;

/// Display phone with a leading '+'.
String get supportPhoneDisplay => '+$supportPhoneDigits';

/// Support email (backend value, else fallback).
String get supportEmail => _email ?? kSupportEmailFallback;

/// Support hours, free text (backend value, else fallback).
String get supportHours => _hours ?? kSupportHoursFallback;

/// Max response time in hours (backend value, else fallback).
int get supportResponseHours => _responseHours ?? kSupportResponseHoursFallback;

/// `tel:` URI for a direct call.
String get supportTelUri => 'tel:+$supportPhoneDigits';

/// `mailto:` URI for the support email.
String get supportMailtoUri => 'mailto:$supportEmail';

/// `wa.me` URI for a WhatsApp chat, optionally pre-filling [text].
String supportWhatsAppUri([String? text]) {
  final base = 'https://wa.me/$_supportWhatsAppDigits';
  if (text == null || text.isEmpty) return base;
  return '$base?text=${Uri.encodeComponent(text)}';
}
