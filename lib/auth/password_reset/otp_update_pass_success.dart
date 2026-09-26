class OtpUpdatePassSuccess {
  final String status;
  final bool success;
  final String message;
  final dynamic data; // Using dynamic as the API returns null here
  final dynamic syncStatus; // Using dynamic as the API returns null here
  final dynamic errorCode; // Using dynamic as the API returns null here

  OtpUpdatePassSuccess({
    required this.status,
    required this.success,
    required this.message,
    this.data,
    this.syncStatus,
    this.errorCode,
  });

  factory OtpUpdatePassSuccess.fromJson(Map<String, dynamic> json) {
    return OtpUpdatePassSuccess(
      status: json['status'] ?? '',
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
      syncStatus: json['sync_status'],
      errorCode: json['error_code'],
    );
  }

  @override
  String toString() =>
      'OtpUpdatePassSuccess(status: $status, success: $success, message: $message)';
}
