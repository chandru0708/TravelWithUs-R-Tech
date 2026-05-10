import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final _storage = FlutterSecureStorage();

  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> get(String url) async {
    return await http.get(Uri.parse(url), headers: await _headers());
  }

  static Future<http.Response> post(String url, Map<String, dynamic> body,
      {bool auth = true}) async {
    return await http.post(Uri.parse(url),
        headers: await _headers(auth: auth), body: jsonEncode(body));
  }

  static Future<http.Response> put(String url, Map<String, dynamic> body) async {
    return await http.put(Uri.parse(url),
        headers: await _headers(), body: jsonEncode(body));
  }

  static Future<http.Response> delete(String url) async {
    return await http.delete(Uri.parse(url), headers: await _headers());
  }
}