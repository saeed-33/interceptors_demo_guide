// lib/core/storage/token_storage.dart
//
// Web-compatible token storage abstraction.
// On native: FlutterSecureStorage.
// On web:    SharedPreferences (plain localStorage) because secure storage is
//            unavailable there. In production use a proper web auth strategy.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();

  static TokenStorage create() {
    if (kIsWeb) {
      return _WebTokenStorage();
    }
    return _NativeTokenStorage();
  }
}

class _NativeTokenStorage implements TokenStorage {
  static const _secureStorage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _secureStorage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _secureStorage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _secureStorage.delete(key: key);

  @override
  Future<void> deleteAll() => _secureStorage.deleteAll();
}

class _WebTokenStorage implements TokenStorage {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> read(String key) async => (await _instance).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _instance).setString(key, value);

  @override
  Future<void> delete(String key) async => (await _instance).remove(key);

  @override
  Future<void> deleteAll() async {
    final prefs = await _instance;
    for (final key in [
      'access_token',
      'refresh_token',
      'aes_encryption_key',
      'aes_iv',
    ]) {
      await prefs.remove(key);
    }
  }
}
