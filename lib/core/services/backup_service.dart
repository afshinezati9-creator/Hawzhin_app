import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';

import 'local_database.dart';

/// پشتیبان‌گیری آفلاین. نسخهٔ ۲ از AES-GCM و PBKDF2 استفاده می‌کند؛
/// واردکردن فایل‌های قدیمی XOR برای سازگاری حفظ شده است.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  final _db = LocalDatabase.instance;

  static const _collections = [
    Collections.notes,
    Collections.accounts,
    Collections.transactions,
    Collections.debts,
    Collections.installments,
    Collections.finGoals,
    Collections.purchaseIntents,
    Collections.budgets,
    Collections.infoItems,
    Collections.stickerSurfaces,
    Collections.stickerActiveId,
    Collections.habits,
    Collections.eisen,
    Collections.programData,
    Collections.planningArchives,
    Collections.emergency,
  ];

  static const int _kdfIterations = 210000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  Future<Map<String, dynamic>> buildBackupData() async {
    final data = <String, dynamic>{
      '_meta': {
        'app': 'hawzhin',
        'version': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'encrypted': false,
      },
    };

    for (final c in _collections) {
      var items = await _db.readAll(c);
      if (c == Collections.infoItems) {
        items = items.map(_stripCardPassword).toList();
      }
      data[c] = items;
    }
    return data;
  }

  Map<String, dynamic> _stripCardPassword(Map<String, dynamic> item) {
    final m = Map<String, dynamic>.from(item);
    final card = m['card'];
    if (card is Map) {
      final cm = Map<String, dynamic>.from(card);
      cm['password'] = '';
      m['card'] = cm;
    }
    return m;
  }

  Uint8List _randomBytes(int length) {
    final random = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List _deriveKey(String pin, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _kdfIterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  Future<String> exportJsonString({String? pin}) async {
    final data = await buildBackupData();
    final raw = const JsonEncoder.withIndent('  ').convert(data);
    if (pin == null || pin.length < 4) return raw;

    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = encrypt.Key(_deriveKey(pin, salt));
    final iv = encrypt.IV(nonce);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm, padding: null),
    );
    final encrypted = encrypter.encrypt(raw, iv: iv);

    return const JsonEncoder.withIndent('  ').convert({
      '_meta': {
        'app': 'hawzhin',
        'version': '1.0.0',
        'encryptionVersion': 2,
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _kdfIterations,
        'cipher': 'AES-256-GCM',
        'exportedAt': DateTime.now().toIso8601String(),
        'encrypted': true,
      },
      'salt': base64.encode(salt),
      'iv': base64.encode(nonce),
      'payload': encrypted.base64,
    });
  }

  Future<void> importJsonString(String content, {String? pin}) async {
    final data = jsonDecode(content) as Map<String, dynamic>;
    Map<String, dynamic> payload = data;
    final meta = data['_meta'];
    final encrypted = meta is Map && meta['encrypted'] == true;

    if (encrypted && data['payload'] is String) {
      if (pin == null || pin.length < 4) {
        throw Exception('این بک‌آپ رمزگذاری شده — PIN لازم است');
      }

      final encryptionVersion = meta is Map ? meta['encryptionVersion'] : null;
      if (encryptionVersion == 2) {
        try {
          final salt = Uint8List.fromList(base64.decode(data['salt'] as String));
          final nonce = Uint8List.fromList(base64.decode(data['iv'] as String));
          if (salt.length != _saltLength || nonce.length != _nonceLength) {
            throw const FormatException('Invalid encryption parameters');
          }
          final key = encrypt.Key(_deriveKey(pin, salt));
          final encrypter = encrypt.Encrypter(
            encrypt.AES(key, mode: encrypt.AESMode.gcm, padding: null),
          );
          final plain = encrypter.decrypt(
            encrypt.Encrypted.fromBase64(data['payload'] as String),
            iv: encrypt.IV(nonce),
          );
          payload = jsonDecode(plain) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('رمز اشتباه است یا فایل پشتیبان دستکاری/خراب شده است.');
        }
      } else {
        // مهاجرت خواندن فایل‌های قدیمی XOR؛ فایل جدید با XOR تولید نمی‌شود.
        final decoded = utf8.decode(base64.decode(data['payload'] as String));
        final plain = _xorCrypt(decoded, pin);
        payload = jsonDecode(plain) as Map<String, dynamic>;
      }
    }

    if (payload['_meta'] == null) {
      throw Exception('فایل پشتیبان معتبر نیست');
    }

    // ابتدا دادهٔ فایل اعتبارسنجی شد؛ سپس دادهٔ فعلی جایگزین می‌شود.
    await _db.clearAll();
    for (final c in _collections) {
      final items = payload[c];
      if (items is List) {
        final maps = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .map((e) => c == Collections.infoItems ? _stripCardPassword(e) : e)
            .toList();
        await _db.writeAll(c, maps);
      }
    }
  }

  /// فقط برای خواندن پشتیبان‌های قدیمی؛ خروجی‌های جدید از AES-GCM استفاده می‌کنند.
  String _xorCrypt(String input, String key) {
    final kb = key.codeUnits;
    final out = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      out.writeCharCode(input.codeUnitAt(i) ^ kb[i % kb.length]);
    }
    return out.toString();
  }

  Future<String> exportToTempFile() async => exportJsonString();
}
