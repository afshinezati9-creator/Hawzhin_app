import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/persian_amount_words.dart';
import '../../providers/finance_provider.dart';
import '../../../domain/entities/account_entity.dart';

/// مرحله مالی آغازین: فقط موجودی نقدی و حساب‌های بانکی ثبت می‌شود.
class FinanceOnboarding extends ConsumerStatefulWidget {
  const FinanceOnboarding({super.key});

  @override
  ConsumerState<FinanceOnboarding> createState() => _FinanceOnboardingState();
}

class _BankRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController balance = TextEditingController(text: '0');
  void dispose() {
    name.dispose();
    balance.dispose();
  }
}

class _FinanceOnboardingState extends ConsumerState<FinanceOnboarding> {
  final _cashController = TextEditingController(text: '0');
  final List<_BankRow> _banks = [_BankRow()];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _cashController.dispose();
    for (final bank in _banks) {
      bank.dispose();
    }
    super.dispose();
  }

  double? _parse(String value) =>
      MoneyFormat.parseAmount(value.trim().isEmpty ? '0' : value.trim());

  Future<void> _finish() async {
    final cash = _parse(_cashController.text);
    final bankBalances = _banks.map((b) => _parse(b.balance.text)).toList();
    if (cash == null || cash < 0 ||
        bankBalances.any((v) => v == null || v < 0)) {
      setState(() => _error = 'موجودی نقدی و حساب‌ها را با عدد معتبر و غیرمنفی وارد کن.');
      return;
    }
    if (_banks.any((b) => (_parse(b.balance.text) ?? 0) > 0 && b.name.text.trim().isEmpty)) {
      setState(() => _error = 'برای هر حساب بانکی دارای موجودی، نام بانک یا حساب را بنویس.');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final finance = ref.read(financeProvider.notifier);
      if (cash! > 0) {
        await finance.addAccount(name: 'پول نقد', type: AccountType.cash, balance: cash);
      }
      for (var i = 0; i < _banks.length; i++) {
        final amount = bankBalances[i]!;
        if (amount <= 0 && _banks[i].name.text.trim().isEmpty) continue;
        await finance.addAccount(
          name: _banks[i].name.text.trim().isEmpty ? 'حساب بانکی ${i + 1}' : _banks[i].name.text.trim(),
          type: AccountType.bank,
          balance: amount,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'ذخیره حساب‌ها انجام نشد. دوباره تلاش کن.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cash = _parse(_cashController.text) ?? 0;
    final bankTotal = _banks.fold<double>(0, (sum, row) => sum + (_parse(row.balance.text) ?? 0));
    final total = cash + bankTotal;
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
              Text('ثبت موجودی اولیه', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('این مرحله فقط موجودی پول نقد و حساب‌های بانکی را می‌گیرد. درآمد، هزینه و مراحل دیگر را بعداً از بخش مالی مدیریت می‌کنی.', style: TextStyle(color: Colors.white, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('۱. پول نقد', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(
          controller: _cashController,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          textDirection: TextDirection.ltr,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(labelText: 'موجودی نقدی', hintText: 'مثلاً 500000', suffixText: 'تومان', prefixIcon: Icon(Icons.payments_outlined), border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('۲. حساب‌های بانکی', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          IconButton(onPressed: _saving ? null : () => setState(() => _banks.add(_BankRow())), tooltip: 'افزودن حساب', icon: const Icon(Icons.add_circle_outline_rounded)),
        ]),
        ...List.generate(_banks.length, (i) {
          final bank = _banks[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextField(controller: bank.name, onChanged: (_) => setState(() => _error = null), decoration: InputDecoration(labelText: 'نام بانک یا حساب ${i + 1}', prefixIcon: const Icon(Icons.account_balance_outlined), border: const OutlineInputBorder()))),
                  if (_banks.length > 1) IconButton(onPressed: _saving ? null : () { setState(() { _banks.removeAt(i).dispose(); }); }, icon: const Icon(Icons.remove_circle_outline_rounded), tooltip: 'حذف حساب'),
                ]),
                const SizedBox(height: 10),
                TextField(controller: bank.balance, keyboardType: const TextInputType.numberWithOptions(decimal: false), textDirection: TextDirection.ltr, onChanged: (_) => setState(() => _error = null), decoration: const InputDecoration(labelText: 'موجودی این حساب', suffixText: 'تومان', border: OutlineInputBorder())),
              ]),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.brand3.withOpacity(0.09), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مجموع موجودی اولیه', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${MoneyFormat.format(total)} تومان', style: theme.textTheme.titleLarge?.copyWith(color: AppColors.brand3, fontWeight: FontWeight.w900)),
            if (total > 0) ...[const SizedBox(height: 4), Text(PersianAmountWords.toman(total), style: theme.textTheme.bodySmall)],
          ]),
        ),
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: AppColors.danger))],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _finish,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward_rounded),
          label: Text(_saving ? 'در حال ذخیره…' : 'ذخیره حساب‌ها و شروع', style: const TextStyle(fontWeight: FontWeight.w900)),
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand3, padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ],
    );
  }
}
