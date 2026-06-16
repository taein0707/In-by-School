import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/life/life.dart';

/// What the background task needs to evaluate life without Firebase.
class LifeSnapshot {
  final Life life;
  final Map<String, int> dailyMinutes; // dateKey → focused minutes
  final String name;
  const LifeSnapshot({required this.life, required this.dailyMinutes, required this.name});
}

/// Tiny SharedPreferences-backed store shared between the app and the
/// WorkManager background isolate (which can't easily use Firestore).
class LocalStore {
  LocalStore._();
  static const _key = 'ocl_life_snapshot';

  static Future<void> saveLifeSnapshot({
    required Life life,
    required Map<String, int> dailyMinutes,
    required String name,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode({'life': life.toMap(), 'daily': dailyMinutes, 'name': name}));
    } catch (_) {}
  }

  static Future<LifeSnapshot?> loadLifeSnapshot() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_key);
      if (s == null) return null;
      final m = jsonDecode(s) as Map<String, dynamic>;
      final daily = (m['daily'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? <String, int>{};
      return LifeSnapshot(
        life: Life.fromMap(Map<String, dynamic>.from(m['life'] as Map)),
        dailyMinutes: daily,
        name: m['name'] as String? ?? '토리',
      );
    } catch (_) {
      return null;
    }
  }
}
