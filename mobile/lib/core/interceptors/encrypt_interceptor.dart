// lib/core/interceptors/encrypt_interceptor.dart
//
// 🔐 ENCRYPTION INTERCEPTOR
// Encrypts request body before sending using AES-256-CBC.
// Decrypts response body after receiving.
// Key is fetched from FlutterSecureStorage (never hardcoded).

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  static const _keyStorageKey = 'aes_encryption_key';
  static const _ivStorageKey = 'aes_iv';

  EncryptInterceptor({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Only encrypt endpoints marked for encryption
    if (options.extra['encrypt'] != true) {
      return handler.next(options);
    }

    if (options.data != null) {
      final encrypter = await _getEncrypter();
      final iv = enc.IV.fromLength(16);

      final plaintext = jsonEncode(options.data);
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // Send as structured envelope
      options.data = {
        'payload': encrypted.base64,
        'iv': iv.base64,
      };

      options.headers['X-Encrypted'] = 'true';
      options.headers['Content-Type'] = 'application/json';
    }

    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final isEncrypted = response.headers.value('X-Encrypted') == 'true' ||
        (response.data is Map && response.data['payload'] != null);

    if (!isEncrypted) {
      return handler.next(response);
    }

    try {
      final encrypter = await _getEncrypter();
      final payload = response.data['payload'] as String;
      final ivBase64 = response.data['iv'] as String;

      final iv = enc.IV.fromBase64(ivBase64);
      final decrypted = encrypter.decrypt64(payload, iv: iv);

      response.data = jsonDecode(decrypted);
    } catch (e) {
      return handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          error: Exception('Failed to decrypt response: $e'),
        ),
      );
    }

    return handler.next(response);
  }

  Future<enc.Encrypter> _getEncrypter() async {
    var keyString = await _storage.read(key: _keyStorageKey);

    if (keyString == null) {
      // Generate and store a new 32-byte key on first run
      final key = enc.Key.fromSecureRandom(32);
      keyString = key.base64;
      await _storage.write(key: _keyStorageKey, value: keyString);
    }

    final key = enc.Key.fromBase64(keyString);
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }
}
