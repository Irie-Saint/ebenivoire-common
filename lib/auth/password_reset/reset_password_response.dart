class ResetPasswordResponse {
  final bool success;
  final String message;

  ResetPasswordResponse({required this.success, required this.message});

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'success': success, 'message': message};

  @override
  String toString() =>
      'ResetPasswordResponse(success: $success, message: $message)';
}
