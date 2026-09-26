class OtpVerificationResponse {
  final String status;
  final bool success;
  final String message;
  final String verificationToken;
  final String email;

  OtpVerificationResponse({
    required this.status,
    required this.success,
    required this.message,
    required this.verificationToken,
    required this.email,
  });

  factory OtpVerificationResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResponse(
      status: json['status'] ?? '',
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      verificationToken: json['verification_token'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'success': success,
    'message': message,
    'verification_token': verificationToken,
    'email': email,
  };

  @override
  String toString() =>
      'OtpVerificationResponse(status: $status, success: $success, message: $message, email: $email)';
}
