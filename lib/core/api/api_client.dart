import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: $statusCode - $message';
}

class ApiClient {
  final http.Client _httpClient;
  final String baseUrl;

  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<T> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    required T Function(dynamic) fromJson,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final headers = await _getHeaders();

    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return fromJson(data);
    } else {
      throw ApiException(response.statusCode, response.body);
    }
  }

  Future<T> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    required T Function(dynamic) fromJson,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return fromJson(data);
    } else {
      throw ApiException(response.statusCode, response.body);
    }
  }

  Future<T> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    required T Function(dynamic) fromJson,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await _httpClient.put(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return fromJson(data);
    } else {
      throw ApiException(response.statusCode, response.body);
    }
  }

  Future<void> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await _httpClient.delete(uri, headers: headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }
}
