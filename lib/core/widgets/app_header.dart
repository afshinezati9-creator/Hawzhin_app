import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../constants/app_constants.dart';
import '../../presentation/widgets/nozhin_logo.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onThemeToggle;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoTap;
  final bool isDark;

  const AppHeader({
    super.key,
    this.onThemeToggle,
    this.onSettingsTap,
    this.onLogoTap,
    this.isDark = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 14,
        right: 14,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 1),
        ),
      ),
      // در RTL: اول = راست، آخر = چپ
      // تنظیمات/تم راست | لوگو و نام چپ
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.settings_rounded,
            onTap: onSettingsTap,
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onTap: onThemeToggle,
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            icon: Icons.info_outline_rounded,
            onTap: () => _showAbout(context),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                child: Text(
                  AppConstants.appName,
                  style: AppTypography.h3.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onLogoTap ?? onSettingsTap,
                child: const HawzhinLogo(
                  size: 42,
                  variant: HawzhinLogoVariant.bookLeaf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

void _showAbout(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.auto_awesome_rounded, size: 34),
      title: const Text('درباره هاوژین'),
      content: const Text(
        'هاوژین همراهی ساده برای یادداشت‌ها، مدیریت مالی، اطلاعات دم‌دستی و برچسب‌های کارهاست. هدف ما کمک به نظم روزمره، با رابطی فارسی و تجربه‌ای آرام است.',
        textAlign: TextAlign.start,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('بستن')),
      ],
    ),
  );
}
