class OtpVerificationRequest {
  final String contact; // Changed from email to contact
  final String otp;
  final String verificationType; // Add verification type

  OtpVerificationRequest({
    required this.contact,
    required this.otp,
    this.verificationType = 'password_reset', // Default to password reset
  });

  // Dynamic endpoint based on verification type
  String get endpoint {
    switch (verificationType) {
      case 'activation':
        return '/auth/verify-email-phone'; // Correct endpoint for activation
      case 'password_reset':
        return '/auth/verify-reset-otp';
      default:
        return '/auth/verify-reset-otp';
    }
  }

  Map<String, dynamic> toJson() => {
    'contact': contact, // API expects 'contact' field
    'otp': otp,
  };

  @override
  String toString() => 'OtpVerificationRequest(contact: $contact, otp: $otp)';
}
