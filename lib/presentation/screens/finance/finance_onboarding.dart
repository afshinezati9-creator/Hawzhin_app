import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/persian_amount_words.dart';
import '../../providers/finance_provider.dart';
import '../../../domain/entities/account_entity.dart';

/// راه‌اندازی سبک مالی: فقط موجودی فعلی را می‌پرسد؛ جزئیات بعداً قابل تکمیل است.
class FinanceOnboarding extends ConsumerStatefulWidget {
  const FinanceOnboarding({super.key});

  @override
  ConsumerState<FinanceOnboarding> createState() => _FinanceOnboardingState();
}

class _FinanceOnboardingState extends ConsumerState<FinanceOnboarding> {
  final _balanceController = TextEditingController(text: '0');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final raw = _balanceController.text.trim();
    final balance = MoneyFormat.parseAmount(raw.isEmpty ? '0' : raw);
    if (balance == null || balance < 0) {
      setState(() => _error = 'موجودی را به‌صورت عدد معتبر وارد کن.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(financeProvider.notifier).addAccount(
        name: 'حساب اصلی',
        type: AccountType.bank,
        balance: balance,
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'ذخیره موجودی انجام نشد. دوباره تلاش کن.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = MoneyFormat.parseAmount(_balanceController.text);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 34),
              SizedBox(height: 14),
              Text('شروع ساده، همین حالا',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('فقط موجودی فعلی‌ات را وارد کن. حساب‌ها، درآمدها و هزینه‌ها را هر وقت خواستی بعداً اضافه می‌کنی.',
                style: TextStyle(color: Colors.white, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('الان چقدر پول در اختیار داری؟',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('مجموع موجودی نقدی و حساب‌ها را می‌توانی یک‌جا وارد کنی.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.65))),
        const SizedBox(height: 16),
        TextField(
          controller: _balanceController,
          autofocus: false,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'موجودی فعلی',
            hintText: 'مثلاً 2500000',
            suffixText: 'تومان',
            prefixIcon: Icon(Icons.payments_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        if (balance != null && balance > 0) ...[
          const SizedBox(height: 8),
          Text(PersianAmountWords.toman(balance),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.brand3, fontWeight: FontWeight.w700)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _finish,
          icon: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.arrow_forward_rounded),
          label: Text(_saving ? 'در حال ذخیره…' : 'ذخیره و شروع',
            style: const TextStyle(fontWeight: FontWeight.w900)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand3,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('بعداً می‌توانی حساب‌های جداگانه و جزئیات مالی را تنظیم کنی.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.55))),
        ),
      ],
    );
  }
}
