import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart' as crypto;
import '../../core/theme/app_colors.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/security/biometric_service.dart';
import 'main_shell.dart';

/// وضعیت انیمیشن اثرانگشت
enum _BioUiState { idle, scanning, success, failed }

/// صفحه قفل حرفه‌ای: PIN + اثرانگشت با انیمیشن قبول/رد
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  static String hashPin(String pin) {
    final digest = crypto.sha256.convert('hawzhin_pin_v2:$pin'.codeUnits);
    return 'sha256:$digest';
  }

  static String _legacyHashPin(String pin) {
    var h = 0x811c9dc5;
    for (final c in 'nozhin_v1_$pin'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static bool matchesPin(String pin, String storedHash) =>
      storedHash == hashPin(pin) || storedHash == _legacyHashPin(pin);

  static bool isLegacyHash(String storedHash) =>
      !storedHash.startsWith('sha256:');

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _busy = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  /// اگر بیومتریک فعال باشد، اول حالت اثرانگشت نشان داده می‌شود
  bool _usePinPad = false;

  _BioUiState _bioState = _BioUiState.idle;

  late final AnimationController _pulseCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _successCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _prepareBiometric();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepareBiometric() async {
    final enabled =
        await SecureStorageService.instance.getBiometricLockEnabled();
    final can = await BiometricService.instance.canCheck;
    if (!mounted) return;
    setState(() {
      _bioEnabled = enabled;
      _bioAvailable = can;
      _usePinPad = !(enabled && can);
    });
    if (enabled && can) {
      // کمی صبر تا UI لود شود، بعد خودکار حسگر
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) await _tryBiometric(auto: true);
    }
  }

  Future<void> _tryBiometric({bool auto = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _bioState = _BioUiState.scanning;
      _error = null;
    });
    HapticFeedback.selectionClick();

    final ok = await BiometricService.instance.authenticate(
      reason: 'برای باز کردن هاوژین، اثر انگشت یا چهره را تأیید کن',
      biometricOnly: true,
    );
    if (!mounted) return;

    if (ok) {
      setState(() => _bioState = _BioUiState.success);
      HapticFeedback.mediumImpact();
      await _successCtrl.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) _goMain();
    } else {
      setState(() {
        _bioState = _BioUiState.failed;
        _busy = false;
        _error = auto
            ? 'اثرانگشت تأیید نشد — دوباره امتحان کن یا رمز بزن'
            : 'اثرانگشت رد شد';
      });
      HapticFeedback.heavyImpact();
      await _shakeCtrl.forward(from: 0);
      if (!mounted) return;
      // برگشت به idle بعد از انیمیشن رد
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted && _bioState == _BioUiState.failed) {
        setState(() => _bioState = _BioUiState.idle);
      }
    }
  }

  void _goMain() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _submit() async {
    if (_pin.length < 4) {
      setState(() => _error = 'حداقل ۴ رقم وارد کن');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final stored = await SecureStorageService.instance.getAppLockPinHash();
    final ok = stored != null && LockScreen.matchesPin(_pin, stored);
    if (!mounted) return;
    if (ok) {
      if (stored != null && LockScreen.isLegacyHash(stored)) {
        await SecureStorageService.instance.saveAppLockPinHash(LockScreen.hashPin(_pin));
      }
      _goMain();
    } else {
      setState(() {
        _busy = false;
        _pin = '';
        _error = 'رمز اشتباه است';
      });
      HapticFeedback.heavyImpact();
      await _shakeCtrl.forward(from: 0);
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 10 || _busy) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length >= 4) {
      _tryAuto();
    }
  }

  Future<void> _tryAuto() async {
    final stored = await SecureStorageService.instance.getAppLockPinHash();
    if (stored == null) return;
    if (LockScreen.matchesPin(_pin, stored)) {
      if (LockScreen.isLegacyHash(stored)) {
        await SecureStorageService.instance.saveAppLockPinHash(LockScreen.hashPin(_pin));
      }
      if (!mounted) return;
      _goMain();
    } else if (_pin.length >= 10) {
      setState(() {
        _pin = '';
        _error = 'رمز اشتباه است';
      });
      HapticFeedback.heavyImpact();
      await _shakeCtrl.forward(from: 0);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Color get _bioColor {
    switch (_bioState) {
      case _BioUiState.success:
        return const Color(0xFF10B981);
      case _BioUiState.failed:
        return const Color(0xFFEF4444);
      case _BioUiState.scanning:
        return AppColors.brand3;
      case _BioUiState.idle:
        return AppColors.brand3;
    }
  }

  IconData get _bioIcon {
    switch (_bioState) {
      case _BioUiState.success:
        return Icons.check_rounded;
      case _BioUiState.failed:
        return Icons.close_rounded;
      default:
        return Icons.fingerprint_rounded;
    }
  }

  String get _bioHint {
    switch (_bioState) {
      case _BioUiState.scanning:
        return 'در حال بررسی اثرانگشت…\nانگشت را روی حسگر نگه دار';
      case _BioUiState.success:
        return 'تأیید شد';
      case _BioUiState.failed:
        return 'رد شد — دوباره لمس کن';
      case _BioUiState.idle:
        return 'برای باز کردن، انگشت را روی حسگر بگذار\nیا روی آیکون زیر بزن';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBio = _bioEnabled && _bioAvailable && !_usePinPad;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: 460,
                ),
                child: IntrinsicHeight(
                child: Column(
                  children: [
              const Spacer(flex: 2),
              // لوگوی قفل
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.brand3.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 32, color: AppColors.brand3),
              ),
              const SizedBox(height: 16),
              Text(
                'قفل هاوژین',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                showBio
                    ? 'ورود با اثرانگشت'
                    : 'رمز عبور را وارد کن',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 28),

              if (showBio) ...[
                // ——— ناحیه اثرانگشت با انیمیشن ———
                AnimatedBuilder(
                  animation: Listenable.merge([_pulse, _shake, _successCtrl]),
                  builder: (context, _) {
                    final scale = _bioState == _BioUiState.scanning ||
                            _bioState == _BioUiState.idle
                        ? _pulse.value
                        : (_bioState == _BioUiState.success
                            ? 0.9 + 0.15 * _successCtrl.value
                            : 1.0);
                    final dx = _bioState == _BioUiState.failed ? _shake.value : 0.0;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: Transform.scale(
                        scale: scale,
                        child: GestureDetector(
                          onTap: _busy && _bioState == _BioUiState.scanning
                              ? null
                              : () => _tryBiometric(),
                          child: Container(
                            width: 128,
                            height: 128,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _bioColor.withOpacity(0.12),
                              border: Border.all(
                                color: _bioColor.withOpacity(0.55),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _bioColor.withOpacity(
                                      _bioState == _BioUiState.scanning
                                          ? 0.35
                                          : 0.15),
                                  blurRadius: _bioState == _BioUiState.scanning
                                      ? 24
                                      : 12,
                                  spreadRadius:
                                      _bioState == _BioUiState.scanning ? 4 : 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              _bioIcon,
                              size: 64,
                              color: _bioColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  _bioHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: _bioState == _BioUiState.failed
                        ? const Color(0xFFEF4444)
                        : _bioState == _BioUiState.success
                            ? const Color(0xFF10B981)
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                if (_error != null && _bioState != _BioUiState.failed) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(flex: 2),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _usePinPad = true;
                            _error = null;
                            _bioState = _BioUiState.idle;
                          }),
                  icon: const Icon(Icons.pin_rounded),
                  label: const Text('ورود با رمز PIN'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _tryBiometric(),
                  child: const Text('تلاش دوباره اثرانگشت'),
                ),
              ] else ...[
                // ——— پد PIN ———
                AnimatedBuilder(
                  animation: _shakeCtrl,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                          _error != null ? _shake.value : 0, 0),
                      child: child,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.brand3.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dotSize = (constraints.maxWidth / 22).clamp(8.0, 16.0);
                        final gap = (constraints.maxWidth / 70).clamp(2.0, 8.0);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(10, (i) {
                            final filled = i < _pin.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: dotSize,
                              height: dotSize,
                              margin: EdgeInsets.symmetric(horizontal: gap),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? AppColors.brand3
                                    : Colors.transparent,
                                border: Border.all(
                                  color: filled
                                      ? AppColors.brand3
                                      : theme.colorScheme.outline.withOpacity(0.45),
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                      ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
                _pad(theme),
                const SizedBox(height: 8),
                if (_bioEnabled && _bioAvailable)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _usePinPad = false;
                              _pin = '';
                              _error = null;
                              _bioState = _BioUiState.idle;
                            });
                            _tryBiometric();
                          },
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('ورود با اثرانگشت'),
                  ),
                if (_busy && _usePinPad)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _pad(ThemeData theme) {
    // اعداد همیشه چپ‌به‌راست (استاندارد صفحه کلید PIN)
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['⌫', '0', '✓'],
    ];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((k) {
                final isSubmit = k == '✓';
                final isDel = k == '⌫';
                return SizedBox(
                  width: 76,
                  height: 76,
                  child: Material(
                    color: isSubmit
                        ? AppColors.brand3
                        : theme.colorScheme.surfaceContainerHighest,
                    elevation: isSubmit ? 2 : 0,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _busy
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              if (isDel) {
                                _backspace();
                              } else if (isSubmit) {
                                _submit();
                              } else {
                                _onDigit(k);
                              }
                            },
                      child: Center(
                        child: isSubmit
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 30)
                            : isDel
                                ? Icon(Icons.backspace_outlined,
                                    size: 26,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7))
                                : Text(
                                    k,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: theme.colorScheme.onSurface,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
