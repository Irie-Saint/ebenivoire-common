class ChangePasswordRequest {
  final String code;
  final String email;
  final String newPassword;

  ChangePasswordRequest({
    required this.code,
    required this.email,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'email': email,
    'new_password': newPassword,
  };

  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) {
    return ChangePasswordRequest(
      code: json['code'] as String,
      email: json['email'] as String,
      newPassword: json['new_password'] as String,
    );
  }
}
