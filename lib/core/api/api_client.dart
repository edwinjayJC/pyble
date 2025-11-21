import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiClient {
  final String baseUrl;
  final SupabaseClient _supabase;

  ApiClient({String? baseUrl, required SupabaseClient supabase})
    : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
      _supabase = supabase;

  Future<Map<String, String>> _getHeaders() async {
    final session = _supabase.auth.currentSession;
    final token = session?.accessToken;

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<T> get<T>(
    String path, {
    Map<String, String>? queryParams,
    T Function(dynamic)? parser,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParams);
    final headers = await _getHeaders();

    final response = await http.get(uri, headers: headers);
    return _handleResponse(response, parser);
  }

  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? parser,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();

    final response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, parser);
  }

  Future<T> put<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? parser,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();

    final response = await http.put(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, parser);
  }

  Future<T> delete<T>(String path, {T Function(dynamic)? parser}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();

    final response = await http.delete(uri, headers: headers);
    return _handleResponse(response, parser);
  }

  Future<T> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? parser,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();

    final response = await http.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, parser);
  }

  T _handleResponse<T>(http.Response response, T Function(dynamic)? parser) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        if (parser != null) {
          return parser(null);
        }
        return null as T;
      }

      final data = jsonDecode(response.body);
      if (parser != null) {
        return parser(data);
      }
      return data as T;
    }

    String message = 'Request failed';
    dynamic errorData;

    try {
      if (response.body.isNotEmpty) {
        errorData = jsonDecode(response.body);
        message = errorData['message'] ?? errorData['error'] ?? message;
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : message;
    }

    throw ApiException(
      message,
      statusCode: response.statusCode,
      data: errorData,
    );
  }
}
