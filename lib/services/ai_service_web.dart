import 'dart:math';

/// Returns a pseudo-unique ID on web (stored separately via SharedPreferences).
Future<String> getPlatformDeviceId() async {
  return 'web_${_randomHex(16)}';
}

String _randomHex(int length) {
  final rng = Random.secure();
  return List.generate(length, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
