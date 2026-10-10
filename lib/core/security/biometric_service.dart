import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:permission_handler/permission_handler.dart';

/// وضعیت قابلیت اثرانگشت روی دستگاه
class BiometricStatus {
  final bool deviceSupported;
  final bool canCheck;
  final bool enrolled;
  final String messageFa;

  const BiometricStatus({
    required this.deviceSupported,
    required this.canCheck,
    required this.enrolled,
    required this.messageFa,
  });

  bool get ready => deviceSupported && canCheck && enrolled;
}

/// اثرانگشت / Face ID — فقط اندروید/iOS
///
/// نکته مهم اندروید: USE_BIOMETRIC مجوز runtime در لیست «دسترسی‌های برنامه»
/// نیست. کاربر باید در تنظیمات امنیتی گوشی اثرانگشت ثبت کند و قفل صفحه
/// داشته باشد؛ سپس local_auth از API سیستم استفاده می‌کند.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isSupported async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> get canCheck async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canBio = await _auth.canCheckBiometrics;
      if (!canBio) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> get availableTypes async {
    if (kIsWeb) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<BiometricStatus> status() async {
    if (kIsWeb) {
      return const BiometricStatus(
        deviceSupported: false,
        canCheck: false,
        enrolled: false,
        messageFa: 'اثرانگشت روی وب کار نمی‌کند؛ روی گوشی اندروید تست کن.',
      );
    }
    try {
      final supported = await _auth.isDeviceSupported();
      final can = await _auth.canCheckBiometrics;
      final types = await _auth.getAvailableBiometrics();
      final enrolled = types.isNotEmpty;

      if (!supported) {
        return const BiometricStatus(
          deviceSupported: false,
          canCheck: false,
          enrolled: false,
          messageFa:
              'این دستگاه حسگر اثرانگشت/چهره پشتیبانی‌شده ندارد یا قفل صفحه غیرفعال است.',
        );
      }
      if (!enrolled) {
        return BiometricStatus(
          deviceSupported: supported,
          canCheck: can,
          enrolled: false,
          messageFa:
              'اثرانگشت در تنظیمات امنیتی گوشی ثبت نشده. برو به: تنظیمات → امنیت → اثرانگشت و یک اثرانگشت اضافه کن. در «دسترسی‌های برنامه» چیزی برای روشن کردن نیست.',
        );
      }
      return BiometricStatus(
        deviceSupported: supported,
        canCheck: can,
        enrolled: true,
        messageFa: 'حسگر آماده است (${types.length} روش). می‌توانی قفل بیومتریک را فعال کنی.',
      );
    } catch (e) {
      return BiometricStatus(
        deviceSupported: false,
        canCheck: false,
        enrolled: false,
        messageFa: 'خطا در بررسی حسگر: $e',
      );
    }
  }

  /// جزئیات برنامه در تنظیمات سیستم (مجوزهای runtime مثل میکروفون)
  Future<bool> openSystemAppSettings() async {
    if (kIsWeb) return false;
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'برای باز کردن هاوژین تأیید هویت کن',
    bool biometricOnly = false,
  }) async {
    if (kIsWeb) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      return ok;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Biometric PlatformException: ${e.code} ${e.message}');
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet) {
        return false;
      }
      // When the caller requires biometrics, never silently fall back to the
      // device PIN/password: report failure so the app can offer its own PIN.
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('Biometric auth error: $e');
      return false;
    }
  }
}
