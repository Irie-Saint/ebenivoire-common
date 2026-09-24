class HttpException implements Exception {
  final String message;
  final int status;
  final String? errorCode;

  HttpException(this.message, this.status, {this.errorCode});

  @override
  String toString() =>
      'HttpException: $message (Status: $status${errorCode != null ? ', Code: $errorCode' : ''})';
}

class UnauthorizedException implements Exception {
  final String message;
  final String? errorCode;

  UnauthorizedException(this.message, {this.errorCode});

  @override
  String toString() =>
      'UnauthorizedException: $message${errorCode != null ? ' (Code: $errorCode)' : ''}';
}
