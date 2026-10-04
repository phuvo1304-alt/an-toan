import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random ID created once on this phone. It is NOT linked to the person or
/// the hardware. The server only uses it to limit how often one phone can call.
Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('device_id');
  if (id == null || id.isEmpty) {
    final rnd = Random.secure();
    id = List.generate(24, (_) => rnd.nextInt(16).toRadixString(16)).join();
    await prefs.setString('device_id', id);
  }
  return id;
}
