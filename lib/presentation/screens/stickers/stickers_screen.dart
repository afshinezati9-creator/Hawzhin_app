import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/jalali.dart';
import '../../widgets/shamsi_date_picker.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../domain/entities/sticker_entities.dart';
import '../../providers/stickers_provider.dart';
import 'sticker_note_card.dart';
import 'surface_background.dart';

final ValueNotifier<bool> _threeStickerColumns = ValueNotifier<bool>(false);

TextDirection _directionForText(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0xFB50 && rune <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      return TextDirection.ltr;
    }
  }
  return TextDirection.rtl;
}

IconData _iconData(String id) {
  switch (id) {
    case 'cart':
      return Icons.shopping_cart_outlined;
    case 'book':
      return Icons.menu_book_outlined;
    case 'calendar':
      return Icons.event_outlined;
    case 'star':
      return Icons.star_outline_rounded;
    case 'heart':
      return Icons.favorite_border_rounded;
    case 'briefcase':
      return Icons.work_outline_rounded;
    case 'coffee':
      return Icons.coffee_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'plane':
      return Icons.flight_outlined;
    case 'music':
      return Icons.music_note_outlined;
    case 'code':
      return Icons.code_rounded;
    case 'brush':
      return Icons.brush_outlined;
    case 'dumbbell':
      return Icons.fitness_center_rounded;
    case 'lock':
      return Icons.lock_outline_rounded;
    default:
      return Icons.check_circle_outline_rounded;
  }
}

/// تب برچسب‌های هوشمند — C1/C2 صحنه + شبکه ۳×۳
class StickersScreen extends ConsumerWidget {
  const StickersScreen({super.key});

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final current = ref.read(stickersProvider).activeSurface;
    if (current == null) return;
    if (current.activeNotes.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حداکثر ۹ برچسب در هر سطح'),
        behavior: SnackBarBehavior.fixed,
      ));
      return;
    }

    final titleCtrl = TextEditingController();
    String color = 'yellow';
    String icon = 'check';
    DateTime? dueDate;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final theme = Theme.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'استیکی‌نت جدید',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'عنوان',
                      hintText: 'مثلاً خرید خانه',
                    ),
                    textDirection: _directionForText(titleCtrl.text),
                    onChanged: (_) => setLocal(() {}),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showShamsiDatePicker(ctx, initial: dueDate ?? DateTime.now());
                      if (picked == null || !ctx.mounted) return;
                      final initialTime = TimeOfDay.fromDateTime(dueDate ?? DateTime.now());
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: initialTime,
                        helpText: 'انتخاب ساعت مهلت',
                      );
                      if (time != null) {
                        setLocal(() => dueDate = DateTime(
                          picked.year, picked.month, picked.day,
                          time.hour, time.minute,
                        ));
                      } else {
                        setLocal(() => dueDate = DateTime(
                          picked.year, picked.month, picked.day,
                          dueDate?.hour ?? 23, dueDate?.minute ?? 59,
                        ));
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(dueDate == null ? 'افزودن تاریخ شمسی (اختیاری)' : 'مهلت: ${Jalali.fromDateTime(dueDate!).format(withMonthName: true)} · ${TimeOfDay.fromDateTime(dueDate!).format(ctx)}'),
                  ),
                  if (dueDate != null)
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                      onPressed: () => setLocal(() => dueDate = null),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('حذف تاریخ'),
                    )),
                  const SizedBox(height: 8),
                  const Text('رنگ', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: stickerNoteColors.entries.map((e) {
                      final sel = color == e.key;
                      return GestureDetector(
                        onTap: () => setLocal(() => color = e.key),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(e.value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel
                                  ? AppColors.brand3
                                  : Colors.black26,
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                          child: sel
                              ? const Icon(Icons.check, size: 14)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('آیکون',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stickerIcons.map((id) {
                      final sel = icon == id;
                      final label = stickerIconLabels[id] ?? id;
                      return InkWell(
                        onTap: () => setLocal(() => icon = id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 64,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.brand3.withOpacity(0.15)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? AppColors.brand3
                                  : theme.colorScheme.outline.withOpacity(0.4),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _iconData(id),
                                size: 20,
                                color: sel
                                    ? AppColors.brand3
                                    : theme.colorScheme.onSurface,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      sel ? FontWeight.w800 : FontWeight.w600,
                                  color: sel
                                      ? AppColors.brand3
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand3,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('ذخیره',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;
    final note = StickerNote(
      id: ref.read(stickersProvider.notifier).newId(),
      title: titleCtrl.text.trim().isEmpty
          ? 'استیکی‌نت جدید'
          : titleCtrl.text.trim(),
      color: color,
      icon: icon,
      dueDate: dueDate,
    );
    await ref.read(stickersProvider.notifier).addNote(current.id, note);
  }

  Future<void> _openChecklist(
    BuildContext context,
    WidgetRef ref,
    StickerNote note,
  ) async {
    final surface = ref.read(stickersProvider).activeSurface;
    if (surface == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _ChecklistSheet(
          surfaceId: surface.id,
          noteId: note.id,
        );
      },
    );
  }


  Future<void> _addSurface(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    SurfaceType type = SurfaceType.wall;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('سطح جدید',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: 'نام سطح',
                    hintText: 'مثلاً دیوار اتاق',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('نوع پس‌زمینه',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SurfaceType.values.map((t) {
                    final sel = type == t;
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: sel,
                      onSelected: (_) => setLocal(() => type = t),
                      selectedColor: AppColors.brand3.withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brand3),
                  child: const Text('ساخت', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          );
        });
      },
    );
    if (ok != true) return;
    await ref.read(stickersProvider.notifier).addSurface(
          nameCtrl.text.trim().isEmpty ? type.label : nameCtrl.text.trim(),
          type,
        );
  }

  Future<void> _manageSurfaces(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(builder: (ctx, ref, _) {
          final state = ref.watch(stickersProvider);
          final list = state.activeSurfaces;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (_, sc) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text('مدیریت سطوح',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      '${MoneyFormat.toPersianDigits('${list.length}')} سطح فعال',
                      style: Theme.of(ctx).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text('سطحی نیست'))
                          : ListView.builder(
                              controller: sc,
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final s = list[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(s.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    subtitle: Text(
                                      '${s.type.label} · ${MoneyFormat.toPersianDigits('${s.activeNotes.length}')} برچسب',
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'archive') {
                                          Navigator.pop(ctx);
                                          await _archiveSurface(
                                              context, ref, s.id, s.name);
                                        } else if (v == 'delete') {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (d) => AlertDialog(
                                              title: const Text('حذف دائمی'),
                                              content: Text(
                                                  'سطح «${s.name}» حذف شود؟'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(d, false),
                                                    child: const Text('لغو')),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(d, true),
                                                    child: const Text('حذف',
                                                        style: TextStyle(
                                                            color: Colors.red))),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await ref
                                                .read(stickersProvider.notifier)
                                                .deleteSurface(s.id);
                                          }
                                        } else if (v == 'edit') {
                                          final c = TextEditingController(
                                              text: s.name);
                                          SurfaceType nt = s.type;
                                          final saved =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (d) =>
                                                StatefulBuilder(
                                              builder: (d, setL) =>
                                                  AlertDialog(
                                                title: const Text(
                                                    'ویرایش سطح'),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller: c,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'نام'),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 6,
                                                      children: SurfaceType
                                                          .values
                                                          .map((t) =>
                                                              ChoiceChip(
                                                                label: Text(t
                                                                    .label),
                                                                selected:
                                                                    nt == t,
                                                                onSelected: (_) =>
                                                                    setL(() =>
                                                                        nt = t),
                                                              ))
                                                          .toList(),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              d, false),
                                                      child:
                                                          const Text('لغو')),
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              d, true),
                                                      child: const Text(
                                                          'ذخیره')),
                                                ],
                                              ),
                                            ),
                                          );
                                          if (saved == true) {
                                            await ref
                                                .read(stickersProvider
                                                    .notifier)
                                                .updateSurface(s.copyWith(
                                                  name: c.text.trim().isEmpty
                                                      ? s.name
                                                      : c.text.trim(),
                                                  type: nt,
                                                ));
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('ویرایش')),
                                        PopupMenuItem(
                                            value: 'archive',
                                            child: Text('آرشیو')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('حذف',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  Future<void> _archiveSurface(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('آرشیو: $name'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'دلیل (اختیاری)',
            hintText: 'مثلاً پروژه تمام شد',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('لغو')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('آرشیو')),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(stickersProvider.notifier)
          .archiveSurface(id, reasonCtrl.text.trim());
    }
  }

  Future<void> _openArchive(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(builder: (ctx, ref, _) {
          final state = ref.watch(stickersProvider);
          final archivedNotes = <({StickerSurface surface, StickerNote note})>[];
          final archivedSurfaces = state.surfaces.where((s) => s.archived).toList();
          for (final s in state.surfaces) {
            for (final n in s.notes) {
              if (n.archived) {
                archivedNotes.add((surface: s, note: n));
              }
            }
          }
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (_, sc) {
              final theme = Theme.of(ctx);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined),
                        const SizedBox(width: 8),
                        Text(
                          'آرشیو',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: sc,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      children: [
                        if (archivedNotes.isEmpty && archivedSurfaces.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text('آرشیو خالی است')),
                          ),
                        if (archivedNotes.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: Text(
                              'برچسب‌ها (${MoneyFormat.toPersianDigits('${archivedNotes.length}')})',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          ...archivedNotes.map((item) {
                            final n = item.note;
                            final s = item.surface;
                            final done =
                                n.tasks.where((t) => t.done).length;
                            final total = n.tasks.length;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {},
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      height: 6,
                                      color: Color(stickerNoteColors[n.color] ?? 0xFFFEF3C7),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 10, 8, 10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w900,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  ref
                                                      .read(stickersProvider
                                                          .notifier)
                                                      .updateNote(
                                                    s.id,
                                                    n.copyWith(
                                                      archived: false,
                                                      archiveNote: '',
                                                      clearArchivedAt: true,
                                                    ),
                                                  );
                                                },
                                                child:
                                                    const Text('بازگردانی'),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'سطح: ${s.name}',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurface
                                                  .withOpacity(0.55),
                                            ),
                                          ),
                                          if (n.archiveNote.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'دلیل: ${n.archiveNote}',
                                              style: theme
                                                  .textTheme.labelSmall,
                                            ),
                                          ],
                                          if (total > 0) ...[
                                            const SizedBox(height: 8),
                                            ...n.tasks.take(6).map((task) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        bottom: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      task.done
                                                          ? Icons
                                                              .check_box_rounded
                                                          : Icons
                                                              .check_box_outline_blank_rounded,
                                                      size: 16,
                                                      color: task.done
                                                          ? AppColors.brand3
                                                          : theme
                                                              .colorScheme
                                                              .outline,
                                                    ),
                                                    const SizedBox(
                                                        width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        task.text,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          decoration: task
                                                                  .done
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                          color: task.done
                                                              ? theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withOpacity(
                                                                      0.45)
                                                              : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            if (total > 6)
                                              Text(
                                                'و ${MoneyFormat.toPersianDigits('${total - 6}')} مورد دیگر…',
                                                style: theme
                                                    .textTheme.labelSmall,
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${MoneyFormat.toPersianDigits('$done')} از ${MoneyFormat.toPersianDigits('$total')} انجام‌شده',
                                              style: theme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.brand3,
                                              ),
                                            ),
                                          ] else
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                      top: 6),
                                              child: Text(
                                                'بدون چک‌لیست',
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.4),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        if (archivedSurfaces.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                            child: Text(
                              'سطوح آرشیو',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          ...archivedSurfaces.map((s) => Card(
                                child: ListTile(
                                  title: Text(s.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  subtitle: Text(
                                    s.archiveNote.isEmpty
                                        ? s.type.label
                                        : 'دلیل: ${s.archiveNote}',
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => ref
                                        .read(stickersProvider.notifier)
                                        .restoreSurface(s.id),
                                    child: const Text('بازگردانی'),
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(stickerFabTickProvider, (prev, next) {
      if (prev != next && next > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _addNote(context, ref);
        });
      }
    });
    final state = ref.watch(stickersProvider);
    final theme = Theme.of(context);

    if (state.isLoading && state.surfaces.isEmpty) {
      return const AppLoading();
    }

    final active = state.activeSurfaces;
    final current = state.activeSurface;
    final notes = current?.activeNotes ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              const Icon(Icons.sticky_note_2_rounded, color: AppColors.brand3),
              const SizedBox(width: 8),
              Text(
                'استیکی‌نت',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'مدیریت سطوح',
                onPressed: () => _manageSurfaces(context, ref),
                icon: const Icon(Icons.more_vert_rounded),
              ),
              IconButton(
                tooltip: 'آرشیو',
                onPressed: () => _openArchive(context, ref),
                icon: Badge(
                  isLabelVisible: state.archiveCount > 0,
                  label: Text(
                    MoneyFormat.toPersianDigits('${state.archiveCount}'),
                    style: const TextStyle(fontSize: 9),
                  ),
                  child: const Icon(Icons.inventory_2_outlined),
                ),
              ),
            ],
          ),
        ),
        // تب سطوح — قابل جابه‌جایی (نگه دار و بکش)
        SizedBox(
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  buildDefaultDragHandles: false,
                  itemCount: active.length,
                  onReorder: (oldIndex, newIndex) {
                    ref
                        .read(stickersProvider.notifier)
                        .reorderSurfaces(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final s = active[index];
                    final on = current?.id == s.id;
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(s.id),
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: ChoiceChip(
                          label: Text(
                            '${s.name} (${MoneyFormat.toPersianDigits('${s.activeNotes.length}')})',
                            style: TextStyle(
                              color: on
                                  ? AppColors.brand3
                                  : theme.colorScheme.onSurface.withOpacity(0.85),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          selected: on,
                          onSelected: (_) => ref
                              .read(stickersProvider.notifier)
                              .setActive(s.id),
                          selectedColor: AppColors.brand3.withOpacity(0.18),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          side: BorderSide(
                            color: on
                                ? AppColors.brand3
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('سطح'),
                  onPressed: () => _addSurface(context, ref),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _threeStickerColumns,
                builder: (context, threeColumns, _) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ActionChip(
                    avatar: Icon(
                      threeColumns ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                      size: 16,
                    ),
                    label: Text(threeColumns ? 'دو ستون' : 'سه ستون'),
                    onPressed: () => _threeStickerColumns.value = !threeColumns,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: current == null
              ? const Center(child: Text('هنوز سطحی نیست'))
              : SurfaceBackground(
                  type: current.type,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: notes.isEmpty
                        ? Builder(builder: (ctx) {
                            final lightBg = SurfaceBackground.isLightSurface(
                              current.type,
                              Theme.of(ctx).brightness,
                            );
                            final fg = lightBg
                                ? const Color(0xFF1E293B)
                                : Colors.white;
                            final fgMuted = lightBg
                                ? const Color(0xFF64748B)
                                : Colors.white.withOpacity(0.85);
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sticky_note_2_outlined,
                                      size: 48, color: fgMuted),
                                  const SizedBox(height: 10),
                                  Text(
                                    'سطح «${current.name}» خالی است',
                                    style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    current.type.label,
                                    style: TextStyle(
                                      color: fgMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () => _addNote(context, ref),
                                    icon: const Icon(Icons.add),
                                    label: const Text('اولین استیکی‌نت'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.brand3,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                        : ValueListenableBuilder<bool>(
                            valueListenable: _threeStickerColumns,
                            builder: (context, threeColumns, _) => GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: threeColumns ? 3 : 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: notes.length +
                                (notes.length < 9 ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == notes.length) {
                                return StickerAddSlot(
                                  onTap: () => _addNote(context, ref),
                                );
                              }
                              final n = notes[i];
                              return StickerNoteCard(
                                note: n,
                                onTap: () =>
                                    _openChecklist(context, ref, n),
                                onMenu: () async {
                                  final action = await showModalBottomSheet<String>(
                                    context: context,
                                    builder: (dctx) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.inventory_2_outlined),
                                            title: const Text('آرشیو برچسب'),
                                            onTap: () => Navigator.pop(dctx, 'archive'),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.delete_outline, color: Colors.red),
                                            title: const Text('حذف دائمی', style: TextStyle(color: Colors.red)),
                                            onTap: () => Navigator.pop(dctx, 'delete'),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.close),
                                            title: const Text('انصراف'),
                                            onTap: () => Navigator.pop(dctx),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (action == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        title: Text(n.title),
                                        content: const Text('حذف دائمی این برچسب؟'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لغو')),
                                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await ref.read(stickersProvider.notifier).deleteNote(current.id, n.id);
                                    }
                                  } else if (action == 'archive') {
                                    final reasonCtrl = TextEditingController();
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        title: const Text('آرشیو برچسب'),
                                        content: TextField(
                                          controller: reasonCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'دلیل (اختیاری)',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لغو')),
                                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('آرشیو')),
                                        ],
                                      ),
                                    );
                                    if (ok == true && context.mounted) {
                                      await ref.read(stickersProvider.notifier).archiveNote(
                                            current.id,
                                            n.id,
                                            reason: reasonCtrl.text.trim(),
                                          );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                          ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChecklistSheet extends ConsumerStatefulWidget {
  final String surfaceId;
  final String noteId;

  const _ChecklistSheet({
    required this.surfaceId,
    required this.noteId,
  });

  @override
  ConsumerState<_ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends ConsumerState<_ChecklistSheet> {
  final _taskCtrl = TextEditingController();
  TextDirection _taskDirection = TextDirection.rtl;

  StickerNote? get _note {
    final s = ref.watch(stickersProvider).surfaces;
    try {
      final surface = s.firstWhere((e) => e.id == widget.surfaceId);
      return surface.notes.firstWhere((n) => n.id == widget.noteId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggle(StickerTask t) async {
    final note = _note;
    if (note == null) return;
    final tasks = note.tasks
        .map((x) => x.id == t.id ? x.nextStatus() : x)
        .toList();
    await ref
        .read(stickersProvider.notifier)
        .updateNote(widget.surfaceId, note.copyWith(tasks: tasks));
  }

  Future<void> _addTask() async {
    final text = _taskCtrl.text.trim();
    if (text.isEmpty) return;
    final note = _note;
    if (note == null) return;
    final task = StickerTask(
      id: ref.read(stickersProvider.notifier).newId(),
      text: text,
    );
    await ref.read(stickersProvider.notifier).updateNote(
          widget.surfaceId,
          note.copyWith(tasks: [...note.tasks, task]),
        );
    _taskCtrl.clear();
    if (mounted) setState(() => _taskDirection = TextDirection.rtl);
  }

  Future<void> _deleteTask(StickerTask t) async {
    final note = _note;
    if (note == null) return;
    await ref.read(stickersProvider.notifier).updateNote(
          widget.surfaceId,
          note.copyWith(tasks: note.tasks.where((x) => x.id != t.id).toList()),
        );
  }

  @override
  void dispose() {
    _taskCtrl.dispose();
    super.dispose();
  }

  Future<void> _editMeta(StickerNote note) async {
    final titleCtrl = TextEditingController(text: note.title);
    var color = note.color;
    var icon = note.icon;
    DateTime? dueDate = note.dueDate;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ویرایش برچسب',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'عنوان'),
                  textDirection: _directionForText(titleCtrl.text),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showShamsiDatePicker(ctx, initial: dueDate ?? DateTime.now());
                    if (picked == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(dueDate ?? DateTime.now()),
                      helpText: 'انتخاب ساعت مهلت',
                    );
                    setLocal(() => dueDate = DateTime(
                      picked.year, picked.month, picked.day,
                      time?.hour ?? dueDate?.hour ?? 23,
                      time?.minute ?? dueDate?.minute ?? 59,
                    ));
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(dueDate == null ? 'افزودن تاریخ شمسی (اختیاری)' : 'مهلت: ${Jalali.fromDateTime(dueDate!).format(withMonthName: true)} · ${TimeOfDay.fromDateTime(dueDate!).format(ctx)}'),
                ),
                if (dueDate != null)
                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                    onPressed: () => setLocal(() => dueDate = null),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('حذف تاریخ'),
                  )),
                const SizedBox(height: 12),
                const Text('رنگ', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: stickerNoteColors.entries.map((e) {
                    final sel = color == e.key;
                    return GestureDetector(
                      onTap: () => setLocal(() => color = e.key),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(e.value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? AppColors.brand3 : Colors.black26,
                            width: sel ? 2.5 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('آیکون',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: stickerIcons.map((id) {
                    final sel = icon == id;
                    final label = stickerIconLabels[id] ?? id;
                    return ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      onSelected: (_) => setLocal(() => icon = id),
                      selectedColor: AppColors.brand3.withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand3),
                  child: const Text('ذخیره',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          );
        });
      },
    );
    if (ok != true) return;
    await ref.read(stickersProvider.notifier).updateNote(
          widget.surfaceId,
          note.copyWith(
            title: titleCtrl.text.trim().isEmpty
                ? note.title
                : titleCtrl.text.trim(),
            color: color,
            icon: icon,
            dueDate: dueDate,
            clearDueDate: dueDate == null,
          ),
        );
  }


  @override
  Widget build(BuildContext context) {
    final note = _note;
    if (note == null) {
      return const SizedBox(height: 120, child: Center(child: Text('یافت نشد')));
    }
    final theme = Theme.of(context);
    final pct = (note.progress * 100).round();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ویرایش',
                    onPressed: () => _editMeta(note),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'آرشیو برچسب',
                    onPressed: () async {
                      final reason = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('آرشیو برچسب'),
                          content: TextField(
                            controller: reason,
                            decoration: const InputDecoration(
                              labelText: 'دلیل (اختیاری)',
                            ),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('لغو')),
                            TextButton(
                                onPressed: () => Navigator.pop(d, true),
                                child: const Text('آرشیو')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref.read(stickersProvider.notifier).updateNote(
                              widget.surfaceId,
                              note.copyWith(
                                archived: true,
                                archiveNote: reason.text.trim(),
                                archivedAt: DateTime.now(),
                              ),
                            );
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brand3.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${MoneyFormat.toPersianDigits('${note.doneCount}')} از ${MoneyFormat.toPersianDigits('${note.totalCount}')} · ${MoneyFormat.toPersianDigits('$pct')}٪',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: note.progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(6),
                      color: note.progress >= 1
                          ? const Color(0xFF059669)
                          : AppColors.brand3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...note.tasks.map((t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconButton(
                      tooltip: t.done ? 'انجام‌شده؛ برای بازنشانی بزن' : (t.inProgress ? 'در حال انجام؛ برای تکمیل بزن' : 'انجام‌نشده؛ برای شروع بزن'),
                      onPressed: () => _toggle(t),
                      icon: Icon(
                        t.done ? Icons.check_circle_rounded : (t.inProgress ? Icons.more_horiz_rounded : Icons.close_rounded),
                        color: t.done ? const Color(0xFF16A34A) : (t.inProgress ? Theme.of(context).colorScheme.onSurface.withOpacity(0.55) : const Color(0xFFDC2626)),
                        size: 26,
                      ),
                    ),
                    title: Text(
                      t.text,
                      style: TextStyle(
                        decoration:
                            t.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _deleteTask(t),
                    ),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taskCtrl,
                      decoration: const InputDecoration(
                        hintText: 'کار جدید…',
                        isDense: true,
                      ),
                      textDirection: _taskDirection,
                      onChanged: (value) => setState(() => _taskDirection = _directionForText(value)),
                      onSubmitted: (_) => _addTask(),
                    ),
                  ),
                  IconButton(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.brand3),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Enter برای افزودن سریع',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
