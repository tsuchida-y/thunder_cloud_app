import 'dart:developer';

/// エラーハンドリングユーティリティ
class ErrorHandler {
  static void handleApiError(dynamic error, String context) {
    log('[$context] Error: $error');
    
    if (error.toString().contains('timeout')) {
      log('[$context] API timeout occurred');
    } else if (error.toString().contains('SocketException')) {
      log('[$context] Network connection error');
    } else {
      log('[$context] Unknown error: $error');
    }
  }
  
  static void logInfo(String message, String context) {
    log('[$context] $message');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}