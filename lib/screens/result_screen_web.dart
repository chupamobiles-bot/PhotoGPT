import 'dart:typed_data';

/// On web, file paths are blob URLs that expire — just return null.
Future<Uint8List?> loadBytesFromPath(String path) async => null;
