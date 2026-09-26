import 'dart:async';
import 'dart:io';
import 'network_exceptions.dart';
import 'package:flutter/material.dart';
import 'server_unreachable.dart';
import 'package:get/get.dart';

export 'server_unreachable.dart' show RetryPausedError;

/// Enhanced retry mixin with intelligent error classification and robust retry logic
///
/// Features:
/// - Smart error classification (retryable vs non-retryable)
/// - Exponential backoff with jitter
/// - Network connectivity awareness
/// - Detailed retry state tracking
/// - Manual retry triggers
/// - Timeout handling
mixin AutoRetryMixin {
  // Retry configuration
  int _maxRetries = 3;
  int _retryDelay = 1000; // milliseconds
  bool _isRetrying = false;
  bool _isCancelled = false;
  Timer? _retryTimer;

  // Enhanced state tracking
  final RxBool isLoading = true.obs;
  final RxBool isRetryingNow = false.obs;
  final RxInt currentRetryAttempt = 0.obs;
  final RxString retryReason = ''.obs;
  final RxString lastError = ''.obs;

  // Track controller route and active status
  String? _currentRoute;
  bool _isPaused = false;

  /// Enhanced backoff pattern with exponential growth and jitter
  List<int> get retryBackoffPattern => [
    1000,
    2000,
    4000,
    8000,
    15000,
    30000,
  ]; // 1s, 2s, 4s, 8s, 15s, 30s

  // Make these getters so they can be overridden in subclasses
  int get maxRetries => _maxRetries;
  int get retryDelay => _retryDelay;

  /// Determine if an error is retryable
  bool isRetryableError(dynamic error) {
    if (error is UnauthorizedException) return false;

    // Network-related errors that should be retried
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) return true;

    // String-based error checking for common network issues
    final errorString = error.toString().toLowerCase();

    // Connection issues
    if (errorString.contains('connection')) return true;
    if (errorString.contains('timeout')) return true;
    if (errorString.contains('network')) return true;
    if (errorString.contains('unreachable')) return true;
    if (errorString.contains('dns')) return true;
    if (errorString.contains('socket')) return true;

    // HTTP status codes that should be retried
    if (errorString.contains('500')) return true; // Internal Server Error
    if (errorString.contains('502')) return true; // Bad Gateway
    if (errorString.contains('503')) return true; // Service Unavailable
    if (errorString.contains('504')) return true; // Gateway Timeout
    if (errorString.contains('408')) return true; // Request Timeout
    if (errorString.contains('429')) return true; // Too Many Requests

    // GetConnect/Dio specific errors
    if (errorString.contains('connecttimeout')) return true;
    if (errorString.contains('receivetimeout')) return true;
    if (errorString.contains('sendtimeout')) return true;

    // Non-retryable errors (logic errors, validation errors, etc.)
    if (errorString.contains('400')) return false; // Bad Request
    if (errorString.contains('401')) return false; // Unauthorized
    if (errorString.contains('unauthorized')) return false; // Unauthorized
    if (errorString.contains('session_revoked')) return false;
    if (errorString.contains('vendor_login_restricted')) return false;
    if (errorString.contains('account_suspended')) return false;
    if (errorString.contains('inactive')) return false;
    if (errorString.contains('403')) return false; // Forbidden
    if (errorString.contains('404')) return false; // Not Found
    if (errorString.contains('validation')) return false;
    if (errorString.contains('invalid')) return false;

    // Default: retry unknown errors (conservative approach)
    return true;
  }

  /// Calculate delay with exponential backoff and jitter
  int calculateRetryDelay(int attempt) {
    final pattern = retryBackoffPattern;
    final baseDelay = attempt < pattern.length
        ? pattern[attempt]
        : pattern.last;

    // Add jitter (±25% randomization) to prevent thundering herd
    final jitter =
        (baseDelay * 0.25 * (DateTime.now().millisecondsSinceEpoch % 100) / 100)
            .round();
    final finalDelay = baseDelay + jitter - (baseDelay * 0.125).round();

    return finalDelay.clamp(500, 60000); // Min 500ms, Max 60s
  }

  /// Configure retry settings
  /// Set maxRetries to -1 for infinite retries
  void configureRetry({int? maxRetries, int? retryDelayMs}) {
    if (maxRetries != null) _maxRetries = maxRetries;
    if (retryDelayMs != null) _retryDelay = retryDelayMs;
  }

  // Enhanced retry method with intelligent error handling
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int? maxRetries,
    int? retryDelay,
    Function(int, dynamic, StackTrace?)? onRetry,
    Function(dynamic, StackTrace?)? onFinalFailure,
    bool? forceRetry, // Override error classification
  }) async {
    // Capture current route when operation starts
    _currentRoute = Get.currentRoute;
    _isCancelled = false;

    // Reset state
    isLoading.value = true;
    isRetryingNow.value = false;
    currentRetryAttempt.value = 0;
    retryReason.value = '';
    lastError.value = '';

    final retries = maxRetries ?? this.maxRetries;
    final infiniteRetries = retries <= -1;

    int attempts = 0;

    while (true) {
      // Check for cancellation before each attempt
      if (_isPaused || _isCancelled) {
        _resetRetryState();
        debugPrint('⚠️ Retry loop exited: controller is paused or cancelled');
        throw RetryPausedError('Retry cancelled or paused');
      }

      try {
        attempts++;
        currentRetryAttempt.value = attempts;
        _isRetrying = attempts > 1;
        isRetryingNow.value = attempts > 1;

        if (attempts > 1) {
          debugPrint(
            '🔄 Retry attempt $attempts/${infiniteRetries ? "∞" : retries} on route $_currentRoute',
          );
          debugPrint('🔄 Retry reason: ${retryReason.value}');
        }

        final result = await operation();

        // Success - reset all state
        _resetRetryState();
        return result;
      } catch (error, stackTrace) {
        lastError.value = error.toString();
        debugPrint('❌ Error in executeWithRetry (attempt $attempts): $error');

        // Check if controller is paused or route has changed
        final currentRoute = Get.currentRoute;
        if (_isPaused ||
            _isCancelled ||
            (_currentRoute != null && _currentRoute != currentRoute)) {
          _resetRetryState();
          debugPrint(
            '⚠️ Cancelling retry because: ${_isPaused
                ? "controller is paused"
                : _isCancelled
                ? "controller is cancelled"
                : "route changed from $_currentRoute to $currentRoute"}',
          );
          rethrow;
        }

        // Check if error is retryable (unless forced)
        final shouldRetry = forceRetry ?? isRetryableError(error);
        if (!shouldRetry) {
          debugPrint('❌ Error is not retryable: $error');
          _resetRetryState();
          if (onFinalFailure != null) {
            onFinalFailure(error, stackTrace);
          }
          rethrow;
        }

        // Set retry reason for UI feedback
        retryReason.value = _getRetryReason(error);

        // Check retry limits
        if (!infiniteRetries && attempts >= retries) {
          debugPrint('❌ Max retries ($retries) exceeded');
          _resetRetryState();
          if (onFinalFailure != null) {
            onFinalFailure(error, stackTrace);
          }
          rethrow;
        }

        // Calculate delay
        final delayMs = infiniteRetries
            ? calculateRetryDelay((attempts - 1) % retryBackoffPattern.length)
            : (retryDelay ?? calculateRetryDelay(attempts - 1));

        // Notify retry callback
        if (onRetry != null) onRetry(attempts, error, stackTrace);

        debugPrint(
          '⏱️ Waiting ${delayMs}ms before retry ${attempts + 1} (reason: ${retryReason.value})',
        );

        // Wait with cancellation support
        _retryTimer?.cancel();
        final completer = Completer<void>();
        _retryTimer = Timer(Duration(milliseconds: delayMs), () {
          if (!completer.isCompleted) completer.complete();
        });

        await completer.future;

        // Check cancellation after delay
        if (_isPaused || _isCancelled) {
          _resetRetryState();
          debugPrint('⚠️ Retry cancelled after delay');
          throw RetryPausedError('Retry cancelled or paused after delay');
        }
      }
    }
  }

  /// Reset all retry state
  void _resetRetryState() {
    _isRetrying = false;
    isLoading.value = false;
    isRetryingNow.value = false;
    currentRetryAttempt.value = 0;
    retryReason.value = '';
  }

  /// Get human-readable retry reason
  String _getRetryReason(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('timeout')) return 'Connection timeout';
    if (errorString.contains('connection')) return 'Connection failed';
    if (errorString.contains('network')) return 'Network error';
    if (errorString.contains('500')) return 'Server error';
    if (errorString.contains('502')) return 'Bad gateway';
    if (errorString.contains('503')) return 'Service unavailable';
    if (errorString.contains('504')) return 'Gateway timeout';
    if (errorString.contains('dns')) return 'DNS resolution failed';
    if (errorString.contains('socket')) return 'Socket error';

    return 'Connection issue';
  }

  // Cancel any ongoing retry timer
  void cancelRetry() {
    _retryTimer?.cancel();
    _isCancelled = true;
    _resetRetryState();
    debugPrint('❌ Auto-retry cancelled for route $_currentRoute');
  }

  // Pause retries (for when controller becomes inactive)
  void pauseRetry() {
    _isPaused = true;
    cancelRetry();
    debugPrint('⏸️ Auto-retry paused for route $_currentRoute');
  }

  // Resume retries (for when controller becomes active again)
  void resumeRetry() {
    _isPaused = false;
    _isCancelled = false;
    debugPrint('▶️ Auto-retry resumed for route $_currentRoute');
  }

  /// Manual retry trigger for user-initiated retries
  Future<T> manualRetry<T>(Future<T> Function() operation) async {
    debugPrint('🔄 Manual retry triggered by user');
    return executeWithRetry(operation, forceRetry: true);
  }

  // Getters for state
  bool get isRetrying => _isRetrying;
  String get currentError => lastError.value;
  String get currentRetryReason => retryReason.value;
  int get retryAttempt => currentRetryAttempt.value;

  // Helper to directly update loading state when needed
  void setLoading(bool loading) {
    isLoading.value = loading;
  }

  /// Get retry status for debugging
  Map<String, dynamic> getRetryStatus() {
    return {
      'isLoading': isLoading.value,
      'isRetrying': isRetryingNow.value,
      'currentAttempt': currentRetryAttempt.value,
      'retryReason': retryReason.value,
      'lastError': lastError.value,
      'hasError': lastError.value.isNotEmpty,
      'isPaused': _isPaused,
      'isCancelled': _isCancelled,
      'currentRoute': _currentRoute,
    };
  }
}
