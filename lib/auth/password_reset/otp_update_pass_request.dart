class OtpUpdatePassRequest {
  final String email;
  final String verificationToken;
  final String newPassword;

  OtpUpdatePassRequest({
    required this.email,
    required this.verificationToken,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'contact': email,
    'verification_token': verificationToken,
    'new_password': newPassword,
  };

  @override
  String toString() =>
      'OtpUpdatePassRequest(contact: $email, token: ${verificationToken.substring(0, 10)}...)';
}
