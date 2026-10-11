import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/nozhin_logo.dart';
import '../../../core/widgets/app_card.dart';
import '../../providers/theme_provider.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/security/biometric_service.dart';
import '../lock_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/services/backup_service.dart';
import '../../../core/services/finance_excel_service.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final name = ref.read(themeProvider).userName;
    _nameController = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: [
          // Profile
          _SettingsGroup(
            title: AppStrings.profile,
            icon: Icons.person_outline_rounded,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: AppStrings.yourName,
                  hintText: 'مثلاً: علی',
                ),
                onChanged: (v) {
                  ref.read(themeProvider.notifier).setUserName(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Appearance
          _SettingsGroup(
            title: 'ظاهر',
            icon: Icons.palette_outlined,
            children: [
              Text(AppStrings.theme, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ThemeChip(
                    label: AppStrings.themeLight,
                    selected: themeState.themeMode == ThemeMode.light,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: AppStrings.themeDark,
                    selected: themeState.themeMode == ThemeMode.dark,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: AppStrings.themeSystem,
                    selected: themeState.themeMode == ThemeMode.system,
                    onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(AppStrings.fontSize, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ThemeChip(
                    label: AppStrings.fontSmall,
                    selected: themeState.fontSize == AppFontSize.small,
                    onTap: () => ref.read(themeProvider.notifier).setFontSize(AppFontSize.small),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: AppStrings.fontMedium,
                    selected: themeState.fontSize == AppFontSize.medium,
                    onTap: () => ref.read(themeProvider.notifier).setFontSize(AppFontSize.medium),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: AppStrings.fontLarge,
                    selected: themeState.fontSize == AppFontSize.large,
                    onTap: () => ref.read(themeProvider.notifier).setFontSize(AppFontSize.large),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Data
          _SettingsGroup(
            title: AppStrings.data,
            icon: Icons.storage_outlined,
            children: [
              _SettingsAction(
                icon: Icons.download_rounded,
                label: AppStrings.exportData,
                onTap: () => _exportBackup(context),
              ),
              _SettingsAction(
                icon: Icons.upload_rounded,
                label: AppStrings.importData,
                onTap: () => _importBackup(context),
              ),
              _SettingsAction(
                icon: Icons.delete_forever_rounded,
                label: AppStrings.clearAllData,
                isDanger: true,
                onTap: () => _clearAll(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // اکسل مالی
          _SettingsGroup(
            title: 'اکسل مالی',
            icon: Icons.table_chart_outlined,
            children: [
              Text(
                'خروجی چندشیتی استاندارد (حساب‌ها، دفترروزنامه، بدهی، اقساط، بودجه، اهداف، قصد خرید، خلاصه). واحد: تومان.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _SettingsAction(
                icon: Icons.file_download_outlined,
                label: 'خروجی اکسل مالی (.xlsx)',
                onTap: () => _exportFinanceExcel(context),
              ),
              _SettingsAction(
                icon: Icons.file_upload_outlined,
                label: 'ورود از اکسل (ادغام با داده فعلی)',
                onTap: () => _importFinanceExcel(context, merge: true),
              ),
              _SettingsAction(
                icon: Icons.sync_problem_rounded,
                label: 'ورود از اکسل (جایگزینی کامل مالی)',
                onTap: () => _importFinanceExcel(context, merge: false),
              ),
            ],
          ),
          const SizedBox(height: 14),


          // امنیت
          _SettingsGroup(
            title: 'امنیت',
            icon: Icons.lock_outline_rounded,
            children: [
              FutureBuilder<bool>(
                future: SecureStorageService.instance.getAppLockEnabled(),
                builder: (context, snap) {
                  final enabled = snap.data ?? false;
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('قفل برنامه با PIN'),
                    subtitle: Text(
                      enabled
                          ? 'فعال — هنگام ورود رمز می‌خواهد'
                          : 'غیرفعال',
                    ),
                    value: enabled,
                    activeThumbColor: AppColors.brand3,
                    onChanged: (v) async {
                      if (v) {
                        final pin = await _askNewPin(context);
                        if (pin == null) return;
                        await SecureStorageService.instance
                            .saveAppLockPinHash(LockScreen.hashPin(pin));
                        await SecureStorageService.instance
                            .saveAppLockEnabled(true);
                      } else {
                        await SecureStorageService.instance
                            .saveAppLockEnabled(false);
                      }
                      if (context.mounted) setState(() {});
                    },
                  );
                },
              ),

// احراز هویت بیومتریک؛ تأیید نهایی را خود سیستم‌عامل نمایش می‌دهد.
              FutureBuilder<bool>(
                future: SecureStorageService.instance.getAppLockEnabled(),
                builder: (context, snap) {
                  final pinOn = snap.data ?? false;
                  return FutureBuilder<bool>(
                    future: SecureStorageService.instance.getBiometricLockEnabled(),
                    builder: (context, bioSnap) {
                      final bioOn = bioSnap.data ?? false;
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('باز شدن با اثر انگشت / چهره'),
                        subtitle: Text(
                          kIsWeb
                              ? 'روی وب در دسترس نیست'
                              : (!pinOn
                                  ? 'برای استفاده، ابتدا قفل PIN را فعال کن'
                                  : (bioOn
                                      ? 'فعال — تأیید بیومتریک هنگام ورود'
                                      : 'پس از تأیید شما و احراز هویت سیستم فعال می‌شود')),
                        ),
                        value: bioOn && pinOn && !kIsWeb,
                        activeThumbColor: AppColors.brand3,
                        onChanged: (kIsWeb || !pinOn)
                            ? null
                            : (enabled) async {
                                if (!enabled) {
                                  await SecureStorageService.instance
                                      .saveBiometricLockEnabled(false);
                                  if (context.mounted) setState(() {});
                                  return;
                                }

                                final status =
                                    await BiometricService.instance.status();
                                if (!context.mounted) return;
                                if (!status.ready) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('اثر انگشت آماده نیست'),
                                      content: Text(
                                        '${status.messageFa}\n\n'
                                        'ابتدا در تنظیمات امنیتی خود گوشی قفل صفحه و اثر انگشت/چهره را ثبت کن؛ '
                                        'این قابلیت در مجوزهای معمول برنامه روشن نمی‌شود.',
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('متوجه شدم'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }

                                final consent = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('فعال‌سازی ورود بیومتریک'),
                                    content: const Text(
                                      'برای فعال شدن ورود با اثر انگشت/چهره، اجازه می‌دهی سیستم‌عامل هویتت را بررسی کند؟ '
                                      'اطلاعات بیومتریک در اختیار هاوژین قرار نمی‌گیرد.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('انصراف'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('ادامه و تأیید'),
                                      ),
                                    ],
                                  ),
                                );
                                if (consent != true || !context.mounted) return;

                                final authenticated =
                                    await BiometricService.instance.authenticate(
                                  reason:
                                      'برای فعال‌سازی ورود بیومتریک، هویت خود را تأیید کن',
                                  biometricOnly: true,
                                );
                                if (!context.mounted) return;
                                if (!authenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تأیید بیومتریک انجام نشد؛ قابلیت فعال نشده است.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                await SecureStorageService.instance
                                    .saveBiometricLockEnabled(true);
                                if (context.mounted) setState(() {});
                              },
                      );
                    },
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تغییر PIN'),
                leading: const Icon(Icons.password_rounded),
                onTap: () async {
                  final pin = await _askNewPin(context);
                  if (pin == null) return;
                  await SecureStorageService.instance
                      .saveAppLockPinHash(LockScreen.hashPin(pin));
                  await SecureStorageService.instance.saveAppLockEnabled(true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('PIN ذخیره شد'),
                      behavior: SnackBarBehavior.fixed,
                    ));
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // درباره ما
          _SettingsGroup(
            title: AppStrings.about,
            icon: Icons.info_outline_rounded,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.brand3.withOpacity(0.14),
                      AppColors.brand2.withOpacity(0.07),
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.brand3.withOpacity(0.22),
                  ),
                ),
                child: Column(
                  children: [
                    const HawzhinLogo(
                      size: 68,
                      variant: HawzhinLogoVariant.bookLeaf,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.appNameEn,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.brand3,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نسخه ${AppConstants.appVersion}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppConstants.aboutBlurb,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurface.withOpacity(0.82),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // قابلیت‌ها و کاربرد
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'چه کارهایی می‌توانی بکنی',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _AboutFeature(
                            icon: Icons.menu_book_rounded,
                            title: 'دفترچه',
                            body:
                                'یادداشت با قالب‌بندی، تصویر، جدول و دسته‌بندی؛ ذخیره روی خود گوشی.',
                          ),
                          _AboutFeature(
                            icon: Icons.account_balance_wallet_rounded,
                            title: 'مالی',
                            body:
                                'حساب، تراکنش، بودجه، بدهی، اقساط، هدف و لیست قصد خرید — بدون اتصال ابری.',
                          ),
                          _AboutFeature(
                            icon: Icons.contact_page_outlined,
                            title: 'دم‌دستی',
                            body:
                                'کارت بانکی، آدرس، کد، لینک و یادداشت‌های حساس با کپی سریع.',
                          ),
                          _AboutFeature(
                            icon: Icons.sticky_note_2_outlined,
                            title: 'استیکی‌نت',
                            body:
                                'برچسب روی سطوح مختلف با چک‌لیست؛ مناسب کار روزانه و یادآوری.',
                          ),
                          _AboutFeature(
                            icon: Icons.lock_rounded,
                            title: 'قفل',
                            body:
                                'PIN و در صورت پشتیبانی گوشی، اثرانگشت/چهره برای ورود.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('سیاست حریم خصوصی'),
                      subtitle: const Text('نحوهٔ ذخیره‌سازی داده‌ها، صدا و فایل‌های پشتیبان'),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://github.com/afshinezati9-creator/Hawzhin_app/blob/main/PRIVACY_POLICY.md',
                        );
                        try {
                          final opened = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('باز کردن لینک ممکن نشد.')),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('باز کردن لینک ممکن نشد.')),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    // سازنده
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'توسعه‌دهنده',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    Text(
                                      AppConstants.developerName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      AppConstants.developerNameEn,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        color: AppColors.brand3,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'اگر باگ دیدی، جایی گیر کردی، یا ایده‌ای برای نسخه بعد داری، مستقیم بنویس. ترجیح می‌دهم بازخورد واقعی بگیرم تا حدس بزنم.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.55,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.72),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                final uri = Uri(
                                  scheme: 'mailto',
                                  path: AppConstants.supportEmail,
                                  queryParameters: {
                                    'subject': 'هاوژین — بازخورد',
                                  },
                                );
                                try {
                                  final ok = await launchUrl(uri);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            AppConstants.supportEmail),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            AppConstants.supportEmail),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand3,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.mail_outline_rounded),
                              label: Text(
                                AppConstants.supportEmail,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // حمایت مالی — شماره بعد از ضربه
                          _SupportCardTile(
                            cardNumber: AppConstants.supportCardNumber,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _askNewPin(BuildContext context) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    var show1 = false;
    var show2 = false;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('تنظیم PIN'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'یک رمز عددی ۴ تا ۱۰ رقمی انتخاب کن.',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                // ترتیب فیلدها معکوس شده تا ابتدا تکرار و سپس PIN وارد شود.
                TextField(
                  controller: c2,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  obscureText: !show2,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                  decoration: InputDecoration(
                    labelText: 'تکرار PIN',
                    counterText: '${c2.text.length}/10',
                    filled: true,
                    prefixIcon: const Icon(Icons.password_rounded),
                    suffixIcon: IconButton(
                      tooltip: show2 ? 'پنهان کردن رمز' : 'نمایش رمز',
                      icon: Icon(show2
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setLocal(() => show2 = !show2),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: c1,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  obscureText: !show1,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                  decoration: InputDecoration(
                    labelText: 'PIN جدید',
                    counterText: '${c1.text.length}/10',
                    filled: true,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: show1 ? 'پنهان کردن رمز' : 'نمایش رمز',
                      icon: Icon(show1
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setLocal(() => show1 = !show1),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('لغو')),
            TextButton(
              onPressed: () {
                final a = c1.text.trim();
                final b = c2.text.trim();
                if (a.length < 4 || a.length > 10) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('رمز باید بین ۴ تا ۱۰ رقم باشد'),
                    behavior: SnackBarBehavior.fixed,
                  ));
                  return;
                }
                if (a != b) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('PIN یکسان نیست'),
                    behavior: SnackBarBehavior.fixed,
                  ));
                  return;
                }
                Navigator.pop(ctx, a);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportFinanceExcel(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('در حال ساخت فایل اکسل…'),
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 2),
      ));
      final path = await FinanceExcelService.instance.exportToFile();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('اکسل مالی آماده شد\n$path'),
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطا در خروجی اکسل: $e'),
        behavior: SnackBarBehavior.fixed,
      ));
    }
  }

  Future<void> _importFinanceExcel(
    BuildContext context, {
    required bool merge,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(merge ? 'ورود اکسل (ادغام)' : 'ورود اکسل (جایگزینی)'),
        content: Text(
          merge
              ? 'رکوردهای هم‌شناسه به‌روز می‌شوند و بقیه اضافه می‌شوند. یادداشت‌ها دست نمی‌خورند.'
              : 'داده‌های مالی فعلی با محتوای فایل جایگزین می‌شوند. این کار برگشت‌ناپذیر است.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ادامه')),
        ],
      ),
    );
    if (confirm != true) return;
    final result =
        await FinanceExcelService.instance.importFromPicker(merge: merge);
    if (!context.mounted) return;
    if (result.cancelled) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطا: ${result.error}'),
        behavior: SnackBarBehavior.fixed,
      ));
      return;
    }
    final summary = result.counts.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key}: ${e.value}')
        .join(' · ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        summary.isEmpty
            ? 'فایلی با دادهٔ قابل‌ورود پیدا نشد'
            : 'ورود انجام شد — $summary\nبرای دیدن تغییرات یک‌بار تب مالی را تازه کن یا برنامه را باز/بسته کن',
      ),
      behavior: SnackBarBehavior.fixed,
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _exportBackup(BuildContext context) async {
    final usePin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پشتیبان‌گیری'),
        content: const Text(
          'می‌خواهی بک‌آپ با PIN رمزگذاری شود؟\n(بدون PIN هم رمز کارت در فایل نمی‌آید)',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('بدون رمز')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('با PIN')),
        ],
      ),
    );
    if (usePin == null) return;
    String? pin;
    if (usePin) {
      pin = await _askNewPin(context);
      if (pin == null) return;
    }
    try {
      final json = await BackupService.instance.exportJsonString(pin: pin);
      await Clipboard.setData(ClipboardData(text: json));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('بک‌آپ در کلیپ‌بورد کپی شد — در فایل متنی ذخیره کن'),
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 3),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطا: $e'),
        behavior: SnackBarBehavior.fixed,
      ));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final ctrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی بک‌آپ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'محتوای JSON بک‌آپ را بچسبان. داده‌های فعلی جایگزین می‌شوند.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'JSON',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN (اگر بک‌آپ رمز داشت)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بازیابی')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final pin = pinCtrl.text.trim();
      await BackupService.instance.importJsonString(
        ctrl.text.trim(),
        pin: pin.isEmpty ? null : pin,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('بازیابی انجام شد — برنامه را یک‌بار ریستارت کن'),
        behavior: SnackBarBehavior.fixed,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطا: $e'),
        behavior: SnackBarBehavior.fixed,
      ));
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک‌سازی همه داده‌ها'),
        content: const Text('این کار برگشت‌ناپذیر است. مطمئنی؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پاک کن', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupService.instance.importJsonString(
        '{"_meta":{"app":"hawzhin","version":"1.0.0"},"notes":[],"accounts":[],"transactions":[],"debts":[],"installments":[],"fin_goals":[],"budgets":[],"info_items":[],"sticker_surfaces":[],"sticker_active_id":[],"habits":[],"eisen":[],"program_data":[],"emergency":[]}',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('همه داده‌ها پاک شد'),
        behavior: SnackBarBehavior.fixed,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطا: $e'),
        behavior: SnackBarBehavior.fixed,
      ));
    }
  }


}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brand3),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: selected ? null : Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _SettingsAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDanger ? AppColors.danger : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.brand3.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.brand3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withOpacity(0.68),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCardTile extends StatefulWidget {
  final String cardNumber;
  const _SupportCardTile({required this.cardNumber});

  @override
  State<_SupportCardTile> createState() => _SupportCardTileState();
}

class _SupportCardTileState extends State<_SupportCardTile> {
  bool _revealed = false;

  String get _masked {
    final n = widget.cardNumber.replaceAll(' ', '');
    if (n.length < 8) return '•••• •••• •••• ••••';
    return '•••• •••• •••• ${n.substring(n.length - 4)}';
  }

  String get _grouped {
    final n = widget.cardNumber.replaceAll(' ', '');
    final buf = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(n[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (!_revealed) {
            setState(() => _revealed = true);
            return;
          }
          await Clipboard.setData(ClipboardData(text: widget.cardNumber));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('شماره کارت کپی شد'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.favorite_outline_rounded,
                  color: AppColors.brand3, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حمایت مالی از توسعه‌دهنده',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _revealed
                          ? _grouped
                          : 'برای نمایش شماره کارت ضربه بزن · ضربه دوباره = کپی',
                      textDirection:
                          _revealed ? TextDirection.ltr : TextDirection.rtl,
                      textAlign: _revealed ? TextAlign.left : TextAlign.start,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: _revealed ? 1.1 : 0,
                        fontWeight:
                            _revealed ? FontWeight.w800 : FontWeight.normal,
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _revealed ? Icons.copy_rounded : Icons.visibility_outlined,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
