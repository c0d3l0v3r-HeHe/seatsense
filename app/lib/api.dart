import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

/// Thin client for the SeatSense API (python -m crowding.api).
class Api {
  Api._();

  static final String base = _resolveBase();

  static String _resolveBase() {
    const env = String.fromEnvironment('API_BASE');
    if (env.isNotEmpty) return env;
    if (kIsWeb) {
      final u = Uri.base;
      // Served by the API itself -> same origin. Served by `flutter run` -> API on :8000.
      if (u.port == 8000 || u.port == 80 || u.port == 443) return u.origin;
      return '${u.scheme}://${u.host}:8000';
    }
    return 'http://localhost:8000';
  }

  static Future<dynamic> _get(String path, [Map<String, String>? q]) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: q);
    final r = await http.get(uri).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw Exception('Server said ${r.statusCode}');
    }
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<List<Json>> stops(String q) async =>
      (await _get('/api/stops', {'q': q, 'limit': '8'}) as List).cast<Json>();

  static Future<Json> plan({
    required String from,
    required String to,
    required String day,
    required String time,
    required String pref,
  }) async =>
      await _get('/api/plan', {'from': from, 'to': to, 'day': day, 'time': time, 'pref': pref}) as Json;

  static Future<List<Json>> routes(String q) async =>
      (await _get('/api/routes', {'q': q, 'limit': '40'}) as List).cast<Json>();

  static Future<Json> route(String r, String day, int hour) async =>
      await _get('/api/route/${Uri.encodeComponent(r)}', {'day': day, 'hour': '$hour'}) as Json;

  static Future<List<Json>> hotspots(String day, int hour) async =>
      (await _get('/api/hotspots', {'day': day, 'hour': '$hour', 'limit': '25'}) as List).cast<Json>();

  static Future<Json> meta() async => await _get('/api/meta') as Json;
}
