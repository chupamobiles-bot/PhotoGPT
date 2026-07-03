import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';

class HistoryService {
  static const _key = 'scan_history';
  static const _maxItems = 50;

  static Future<List<ScanResult>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return ScanResult.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(ScanResult result) async {
    final history = await load();
    history.insert(0, result);
    if (history.length > _maxItems) history.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ScanResult.listToJson(history));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> delete(String id) async {
    final history = await load();
    history.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ScanResult.listToJson(history));
  }
}
