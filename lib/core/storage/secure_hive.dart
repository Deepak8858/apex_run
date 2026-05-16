import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Opens a Hive box encrypted with a 256-bit AES key persisted in the
/// platform secure store (Keychain on iOS, EncryptedSharedPreferences on Android).
///
/// The key is generated once on first launch and never leaves the secure store.
class SecureHive {
  static const _keyName = 'hive_master_key_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Open an encrypted box of the given type + name.
  static Future<Box<T>> openBox<T>(String name) async {
    final cipher = HiveAesCipher(await _getOrCreateKey());
    return Hive.openBox<T>(name, encryptionCipher: cipher);
  }

  static Future<List<int>> _getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      return base64Decode(existing);
    }
    final fresh = Hive.generateSecureKey();
    await _storage.write(key: _keyName, value: base64Encode(fresh));
    return fresh;
  }
}
