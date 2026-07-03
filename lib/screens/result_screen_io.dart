import 'dart:io';
import 'dart:typed_data';

/// Load image bytes from a file path (mobile/desktop).
Future<Uint8List?> loadBytesFromPath(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) return await file.readAsBytes();
  } catch (_) {}
  return null;
}
