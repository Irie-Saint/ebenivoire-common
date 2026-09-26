class OtpSuccess {
  final String status;
  final bool success;
  final String message;
  final String email;

  OtpSuccess({
    required this.status,
    required this.success,
    required this.message,
    required this.email,
  });

  factory OtpSuccess.fromJson(Map<String, dynamic> json) {
    return OtpSuccess(
      status: json['status'] ?? '',
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'success': success,
    'message': message,
    'email': email,
  };

  @override
  String toString() =>
      'OtpSuccess(status: $status, success: $success, message: $message, email: $email)';
}
