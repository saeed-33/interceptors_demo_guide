// lib/core/interceptors/encrypt_interceptor.dart
//
// 🔐 ENCRYPTION INTERCEPTOR
// Encrypts request body before sending using AES-256-CBC.
// Decrypts response body after receiving.
// Key is fetched from secure storage (never hardcoded in production).

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'package:interceptors_demo/core/logs/log_store.dart';
import 'package:interceptors_demo/core/storage/token_storage.dart';

class EncryptInterceptor extends Interceptor {
  final TokenStorage _storage;
  static const _keyStorageKey = 'aes_encryption_key';

  EncryptInterceptor({TokenStorage? storage})
      : _storage = storage ?? TokenStorage.create();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requestId = options.extra['request_id'] as String? ?? options.path;

    // Only encrypt endpoints marked for encryption
    if (options.extra['encrypt'] != true) {
      return handler.next(options);
    }

    logInterceptor(
      'encrypt',
      'encrypt request body for ${options.path}',
      api: options.path,
      requestId: requestId,
    );

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
      logInterceptor(
        'encrypt',
        'body encrypted (${encrypted.bytes.length} bytes)',
        api: options.path,
        requestId: requestId,
      );
    }

    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final requestId = response.requestOptions.extra['request_id'] as String? ??
        response.requestOptions.path;
    final isEncrypted = response.headers.value('X-Encrypted') == 'true' ||
        (response.data is Map && response.data['payload'] != null);

    if (!isEncrypted) {
      return handler.next(response);
    }

    logInterceptor(
      'encrypt',
      'decrypt response body for ${response.requestOptions.path}',
      api: response.requestOptions.path,
      requestId: requestId,
    );

    try {
      final encrypter = await _getEncrypter();
      final payload = response.data['payload'] as String;
      final ivBase64 = response.data['iv'] as String;

      final iv = enc.IV.fromBase64(ivBase64);
      final decrypted = encrypter.decrypt64(payload, iv: iv);

      response.data = jsonDecode(decrypted);
      logInterceptor(
        'encrypt',
        'response decrypted successfully',
        api: response.requestOptions.path,
        requestId: requestId,
      );
    } catch (e) {
      logInterceptor(
        'encrypt',
        'decryption failed ($e)',
        api: response.requestOptions.path,
        requestId: requestId,
      );
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
    var keyString = await _storage.read(_keyStorageKey);

    if (keyString == null) {
      // Demo: use a fixed key so client and backend can talk.
      // The backend uses the first 32 UTF-8 bytes of this string.
      // In production this should come from a secure key exchange/derivation.
      const demoKey = 'demo-secret-key-32-bytes-exactly!!';
      keyString = enc.Key.fromUtf8(demoKey.substring(0, 32)).base64;
      await _storage.write(_keyStorageKey, keyString);
    }

    final key = enc.Key.fromBase64(keyString);
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }
}
