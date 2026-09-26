class ChangePasswordResponse {
  final bool success;
  final String message;

  ChangePasswordResponse({required this.success, required this.message});

  factory ChangePasswordResponse.fromJson(Map<String, dynamic> json) {
    return ChangePasswordResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'success': success, 'message': message};

  @override
  String toString() =>
      'ChangePasswordResponse(success: $success, message: $message)';
}
