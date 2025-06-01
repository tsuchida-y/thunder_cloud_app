import 'dart:convert';
import 'package:http/http.dart' as http;
import 'error_handler.dart';

/// API共通処理ヘルパー
class ApiHelper {
  static Future<Map<String, dynamic>> fetchJsonData(
    String url, {
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw ApiException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      ErrorHandler.handleApiError(e, 'fetchJsonData');
      rethrow;
    }
  }
}