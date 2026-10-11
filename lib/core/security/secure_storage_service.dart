import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final Map<String, String> _webFallback = {};

  static const _keyThemeMode = 'theme_mode';
  static const _keyFontSize = 'font_size';
  static const _keyFontFamily = 'font_family';
  static const _keyUserName = 'user_name';
  static const _keyAppLockEnabled = 'app_lock_enabled';
  static const _keyAppLockPin = 'app_lock_pin_hash';
  static const _keyBiometricLock = 'app_lock_biometric';
  static const _keyIsFirstLaunch = 'is_first_launch';
  static const _keyNoteCategories = 'note_categories';
  static const _keyEncryptionKey = 'db_encryption_key';

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      if (kIsWeb) _webFallback[key] = value;
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      if (kIsWeb) return _webFallback[key];
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      _webFallback.remove(key);
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    _webFallback.clear();
  }

  Future<void> saveThemeMode(String mode) => write(_keyThemeMode, mode);
  Future<String?> getThemeMode() => read(_keyThemeMode);

  Future<void> saveFontSize(String size) => write(_keyFontSize, size);
  Future<String?> getFontSize() => read(_keyFontSize);
  Future<void> saveFontFamily(String family) => write(_keyFontFamily, family);
  Future<String?> getFontFamily() => read(_keyFontFamily);

  Future<void> saveUserName(String name) => write(_keyUserName, name);
  Future<String?> getUserName() => read(_keyUserName);

  Future<void> saveAppLockEnabled(bool enabled) =>
      write(_keyAppLockEnabled, enabled.toString());
  Future<bool> getAppLockEnabled() async {
    final v = await read(_keyAppLockEnabled);
    return v == 'true';
  }

  Future<void> saveAppLockPinHash(String hash) => write(_keyAppLockPin, hash);
  Future<String?> getAppLockPinHash() => read(_keyAppLockPin);

  Future<void> saveBiometricLockEnabled(bool enabled) =>
      write(_keyBiometricLock, enabled.toString());
  Future<bool> getBiometricLockEnabled() async {
    final v = await read(_keyBiometricLock);
    return v == 'true';
  }

  Future<void> setFirstLaunchDone() => write(_keyIsFirstLaunch, 'false');
  Future<bool> isFirstLaunch() async {
    final v = await read(_keyIsFirstLaunch);
    return v == null || v == 'true';
  }

  Future<String?> getOrCreateEncryptionKey() async {
    var key = await read(_keyEncryptionKey);
    if (key == null || key.isEmpty) {
      final random = math.Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await write(_keyEncryptionKey, key);
    }
    return key;
  }

  Future<void> saveNoteCategories(String json) => write(_keyNoteCategories, json);
  Future<String?> getNoteCategories() => read(_keyNoteCategories);

}
