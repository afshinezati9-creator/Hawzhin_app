import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../domain/entities/info_item_entity.dart';
import '../../providers/info_provider.dart';
import 'bank_card_widget.dart';
import 'info_form_screen.dart';
import 'info_type_tiles.dart';

class InfoScreen extends ConsumerStatefulWidget {
  const InfoScreen({super.key});

  @override
  ConsumerState<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends ConsumerState<InfoScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openForm({InfoItemEntity? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InfoFormScreen(existing: item)),
    );
  }

  Future<void> _delete(InfoItemEntity item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف؟'),
        content: Text('«${item.title}» حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(infoProvider.notifier).delete(item.id);
    }
  }

  Future<void> _copyValue(InfoItemEntity item) async {
    final text = item.value;
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    await ref.read(infoProvider.notifier).registerCopy(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('کپی شد'),
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 1),
      ),
    );
  }

  IconData _iconFor(InfoItemType t) {
    switch (t) {
      case InfoItemType.text:
        return Icons.notes_rounded;
      case InfoItemType.link:
        return Icons.link_rounded;
      case InfoItemType.code:
        return Icons.code_rounded;
      case InfoItemType.card:
        return Icons.credit_card_rounded;
      case InfoItemType.address:
        return Icons.location_on_outlined;
      case InfoItemType.note:
        return Icons.sticky_note_2_outlined;
      case InfoItemType.image:
        return Icons.image_outlined;
      case InfoItemType.prompt:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(infoProvider);
    final theme = Theme.of(context);
    final items = state.filtered;

    if (state.isLoading && state.items.isEmpty) {
      return const AppLoading();
    }

    return Column(
      children: [
        // جستجو
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) =>
                ref.read(infoProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'جستجو در اطلاعات…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(infoProvider.notifier).setSearch('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        // فیلتر نوع
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(
                    'همه',
                    style: TextStyle(
                      color: state.filterType == null
                          ? AppColors.brand3
                          : theme.colorScheme.onSurface.withOpacity(0.85),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  selected: state.filterType == null,
                  onSelected: (_) =>
                      ref.read(infoProvider.notifier).setFilter(null),
                  selectedColor: AppColors.brand3.withOpacity(0.18),
                  backgroundColor: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surfaceContainerHighest
                      : const Color(0xFFEEF2FF),
                  side: BorderSide(
                    color: state.filterType == null
                        ? AppColors.brand3
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
              ...InfoItemType.values.where((t) => t != InfoItemType.note).map((t) {
                final sel = state.filterType == t;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    avatar: Icon(_iconFor(t),
                        size: 15,
                        color: sel ? AppColors.brand3 : Theme.of(context).colorScheme.onSurface),
                    label: Text(
                      t.label,
                      style: TextStyle(
                        fontWeight:
                            sel ? FontWeight.w900 : FontWeight.w600,
                        color: sel
                            ? AppColors.brand3
                            : theme.colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                    selected: sel,
                    showCheckmark: false,
                    onSelected: (_) =>
                        ref.read(infoProvider.notifier).setFilter(t),
                    selectedColor: AppColors.brand3.withOpacity(0.18),
                    backgroundColor: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surfaceContainerHighest
                      : const Color(0xFFEEF2FF),
                    side: BorderSide(
                      color: sel
                          ? AppColors.brand3
                          : theme.colorScheme.outline,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${MoneyFormat.toPersianDigits('${items.length}')} آیتم',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? AppEmptyState(
                  icon: Icons.info_outline_rounded,
                  message: state.searchQuery.isNotEmpty ||
                          state.filterType != null
                      ? 'نتیجه‌ای پیدا نشد'
                      : 'هنوز چیزی ذخیره نکردی\nبا + کارت بانکی، لینک، کد و… اضافه کن',
                  actionLabel: 'افزودن',
                  onAction: () => _openForm(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    if (item.type == InfoItemType.card) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BankCardWidget(
                          item: item,
                          onEdit: () => _openForm(item: item),
                          onDelete: () => _delete(item),
                          onCopied: (_) => ref
                              .read(infoProvider.notifier)
                              .registerCopy(item.id),
                        ),
                      );
                    }
                    final onCopy = () => ref
                        .read(infoProvider.notifier)
                        .registerCopy(item.id);
                    final onEdit = () => _openForm(item: item);
                    final onDelete = () => _delete(item);
                    switch (item.type) {
                      case InfoItemType.link:
                        return LinkInfoTile(
                          item: item,
                          onCopied: onCopy,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        );
                      case InfoItemType.code:
                        return CodeInfoTile(
                          item: item,
                          onCopied: onCopy,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        );
                      case InfoItemType.address:
                        return AddressInfoTile(
                          item: item,
                          onCopied: onCopy,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        );
                      case InfoItemType.image:
                        return ImageInfoTile(
                          item: item,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        );
                      case InfoItemType.prompt:
                      case InfoItemType.text:
                      case InfoItemType.note:
                      default:
                        return TextNoteInfoTile(
                          item: item,
                          onCopied: onCopy,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        );
                    }
                  },
                ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final InfoItemEntity item;
  final IconData icon;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InfoTile({
    required this.item,
    required this.icon,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: theme.brightness == Brightness.dark ? 0 : 1,
        shadowColor: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onCopy,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                theme.brightness == Brightness.dark ? 0.48 : 0.42,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
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
                            item.title.isEmpty ? item.typeLabel : item.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            item.typeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'کپی',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.value.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.value,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textDirection:
                          item.type == InfoItemType.link ||
                                  item.type == InfoItemType.code
                              ? TextDirection.ltr
                              : null,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: item.type == InfoItemType.code
                            ? 'monospace'
                            : null,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${MoneyFormat.toPersianDigits('${item.uses}')} بار استفاده',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
