import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Returns a device-unique ID on Android/iOS.
Future<String> getPlatformDeviceId() async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final d = await info.androidInfo;
      return d.id; // Android ID
    } else if (Platform.isIOS) {
      final d = await info.iosInfo;
      return d.identifierForVendor ?? _fallbackId();
    }
  } catch (_) {}
  return _fallbackId();
}

String _fallbackId() {
  // Simple timestamp-based fallback
  return 'device_${DateTime.now().millisecondsSinceEpoch}';
}
