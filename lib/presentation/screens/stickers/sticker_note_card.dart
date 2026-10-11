import 'package:flutter/material.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/jalali.dart';
import '../../../domain/entities/sticker_entities.dart';

class StickerNoteCard extends StatelessWidget {
  final StickerNote note;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  const StickerNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onMenu,
  });

  Color get _baseColor {
    final hex = stickerNoteColors[note.color] ?? 0xFFFEF3C7;
    return Color(hex);
  }

  /// در تم تاریک: برگه کمی تیره‌تر و قابل‌خواندن؛ در روشن: روشن و کاغذی
  Color _paperColor(Brightness brightness) {
    final base = _baseColor;
    if (brightness == Brightness.dark) {
      // مخلوط با خاکستری تیره تا روی پس‌زمینه تیره بدرخشد
      return Color.alphaBlend(base.withOpacity(0.55), const Color(0xFF1E2430));
    }
    return base;
  }

  Color _ink(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1F2937);
  }

  Color _muted(Brightness brightness) {
    return brightness == Brightness.dark
        ? Colors.white.withOpacity(0.55)
        : Colors.black.withOpacity(0.45);
  }

  IconData get _icon {
    switch (note.icon) {
      case 'cart':
        return Icons.shopping_cart_outlined;
      case 'book':
        return Icons.menu_book_outlined;
      case 'calendar':
        return Icons.calendar_today_outlined;
      case 'star':
        return Icons.star_outline;
      case 'heart':
        return Icons.favorite_border;
      case 'briefcase':
        return Icons.work_outline;
      case 'coffee':
        return Icons.coffee_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'plane':
        return Icons.flight_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'code':
        return Icons.code;
      case 'brush':
        return Icons.brush_outlined;
      case 'dumbbell':
        return Icons.fitness_center;
      case 'lock':
        return Icons.lock_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = _paperColor(brightness);
    final ink = _ink(brightness);
    final muted = _muted(brightness);
    final tasks = note.tasks.take(4).toList();
    final extra = note.tasks.length - tasks.length;
    final done = note.tasks.where((t) => t.done).length;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                    brightness == Brightness.dark ? 0.35 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // نوار چسب
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: CustomPaint(painter: _TapePainter()),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: ink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_icon, size: 16, color: ink),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              note.title.isEmpty ? 'بدون عنوان' : note.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                height: 1.2,
                                color: ink,
                              ),
                            ),
                          ),
                          if (onMenu != null)
                            InkWell(
                              onTap: onMenu,
                              child: Icon(Icons.more_vert,
                                  size: 18, color: muted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (tasks.isEmpty)
                        Text(
                          'هنوز تسکی نیست',
                          style: TextStyle(fontSize: 12, color: muted),
                        )
                      else
                        ...tasks.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    t.done
                                        ? Icons.check_circle_rounded
                                        : (t.inProgress ? Icons.more_horiz_rounded : Icons.close_rounded),
                                    size: 14,
                                    color: t.done
                                        ? const Color(0xFF16A34A)
                                        : (t.inProgress ? muted : const Color(0xFFDC2626)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      t.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ink.withOpacity(
                                            t.done ? 0.5 : 0.9),
                                        decoration: t.done
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      if (extra > 0)
                        Text(
                          '+${MoneyFormat.toPersianDigits('$extra')} مورد دیگر',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      if (note.dueDate != null) ...[
                        const SizedBox(height: 6),
                        Builder(builder: (context) {
                          final now = DateTime.now();
                          final overdue = !note.done &&
                              note.dueDate!.isBefore(now);
                          final dueSoon = !overdue &&
                              !note.done &&
                              note.dueDate!.difference(now).inHours < 24;
                          final dueColor = overdue
                              ? const Color(0xFFDC2626)
                              : dueSoon
                                  ? const Color(0xFFD97706)
                                  : muted;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: double.infinity),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: dueColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: dueColor.withOpacity(0.22)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                                    size: 12,
                                    color: dueColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${Jalali.fromDateTime(note.dueDate!).format(withMonthName: true)} · ${TimeOfDay.fromDateTime(note.dueDate!).format(context)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: dueColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      const Spacer(),
                      Text(
                        '${MoneyFormat.toPersianDigits('$done')}/${MoneyFormat.toPersianDigits('${note.tasks.length}')} کار',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// خانه «افزودن» در گرید استیکی‌نت
class StickerAddSlot extends StatelessWidget {
  final VoidCallback onTap;
  const StickerAddSlot({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: theme.colorScheme.outline.withOpacity(isDark ? 0.45 : 0.55),
            radius: 14,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 36,
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                ),
                const SizedBox(height: 6),
                Text(
                  'برچسب جدید',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w700,
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

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
