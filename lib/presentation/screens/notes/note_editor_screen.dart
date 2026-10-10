import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/note_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/jalali.dart';
import '../../../domain/entities/note_entity.dart';
import '../../providers/notes_provider.dart';
import '../../providers/categories_provider.dart';
import 'editor/editor_constants.dart';
import 'editor/note_templates.dart';
import 'editor/table_dialog.dart';
import 'editor/quill_embeds.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteEntity note;
  final bool isNew;

  const NoteEditorScreen({
    super.key,
    required this.note,
    this.isNew = false,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late QuillController _quill;
  late String _color;
  late String _category;
  late bool _pinned;
  bool _saving = false;
  bool _dirty = false;
  Timer? _autoSaveTimer;
  bool _fullscreen = false;
  EditorToolTab _toolTab = EditorToolTab.format;
  final _editorFocus = FocusNode();
  final _editorScrollCtrl = ScrollController();
  final _tabScrollCtrl = ScrollController();

  int _words = 0;
  int _chars = 0;
  int _checkDone = 0;
  int _checkTotal = 0;

  // ضبط صدا (نمایشی)
  bool _recording = false;
  int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _color = widget.note.color;
    _category = widget.note.category;
    _pinned = widget.note.pinned;
    _quill = _loadController(widget.note.body);
    _quill.addListener(_updateStats);
    _quill.addListener(_onContentChanged);
    _titleCtrl.addListener(_onContentChanged);
    _updateStats();
  }

  void _onContentChanged() {
    _dirty = true;
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || !_dirty) return;
      _save(pop: false, silent: true);
    });
  }

  QuillController _loadController(String body) {
    if (body.trim().isEmpty) return QuillController.basic();
    try {
      final json = jsonDecode(body);
      if (json is List) {
        return QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {}
    final doc = Document()..insert(0, body);
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _updateStats() {
    final plain = _quill.document.toPlainText();
    final words = plain
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final chars = plain.replaceAll('\n', '').length;
    int done = 0, total = 0;
    for (final op in _quill.document.toDelta().toList()) {
      final attrs = op.attributes;
      if (attrs != null && attrs[Attribute.list.key] != null) {
        final v = attrs[Attribute.list.key];
        if (v == 'checked' || v == 'unchecked') {
          total++;
          if (v == 'checked') done++;
        }
      }
    }
    if (mounted) {
      setState(() {
        _words = words;
        _chars = chars;
        _checkDone = done;
        _checkTotal = total;
      });
    }
  }

  @override
  void deactivate() {
    _autoSaveTimer?.cancel();
    if (_dirty) {
      final updated = widget.note.copyWith(
        title: _titleCtrl.text.trim(),
        body: _bodyJson(),
        color: _color,
        category: _category,
        pinned: _pinned,
      );
      ref.read(notesProvider.notifier).updateNote(updated);
      _dirty = false;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleCtrl.removeListener(_onContentChanged);
    _titleCtrl.dispose();
    _quill.removeListener(_updateStats);
    _quill.removeListener(_onContentChanged);
    _quill.dispose();
    _editorFocus.dispose();
    _editorScrollCtrl.dispose();
    _tabScrollCtrl.dispose();
    super.dispose();
  }

  TextDirection _directionForText(String text) {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return TextDirection.rtl;
    if (RegExp(r'[A-Za-z]').hasMatch(text)) return TextDirection.ltr;
    return TextDirection.rtl;
  }

  String _bodyJson() => jsonEncode(_quill.document.toDelta().toJson());

  Future<void> _save({bool pop = true, bool silent = false}) async {
    if (_saving && silent) return;
    if (!silent && mounted) setState(() => _saving = true);
    final updated = widget.note.copyWith(
      title: _titleCtrl.text.trim(),
      body: _bodyJson(),
      color: _color,
      category: _category,
      pinned: _pinned,
    );
    try {
      await ref.read(notesProvider.notifier).updateNote(updated);
      _dirty = false;
    } catch (_) {}
    if (mounted) {
      if (!silent) setState(() => _saving = false);
      if (pop) Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف یادداشت'),
        content: const Text('این یادداشت حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(notesProvider.notifier).deleteNote(widget.note.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ---------- helpers قالب‌بندی ----------
  void _insertText(String text) {
    final i = _quill.selection.baseOffset.clamp(0, _quill.document.length - 1);
    final end = _quill.selection.extentOffset;
    final len = (end - i).abs();
    final start = i < end ? i : end;
    _quill.replaceText(
      start,
      len,
      text,
      TextSelection.collapsed(offset: start + text.length),
    );
    _editorFocus.requestFocus();
  }

  void _applyAttr(Attribute attr) {
    _quill.formatSelection(attr);
    _editorFocus.requestFocus();
  }

  void _toggleAttr(Attribute attr) {
    final style = _quill.getSelectionStyle();
    final current = style.attributes[attr.key];
    if (current != null && current.value == attr.value) {
      _quill.formatSelection(Attribute.clone(attr, null));
    } else {
      _quill.formatSelection(attr);
    }
    _editorFocus.requestFocus();
  }

  /// اعمال رنگ فقط روی انتخاب — بعدش استایل چسبنده پاک می‌شود
  void _applyColorToSelection(String? hex, {required bool background}) {
    final sel = _quill.selection;
    if (!sel.isValid) return;

    final key = background ? 'background' : 'color';
    if (hex == null) {
      // حذف
      _quill.formatSelection(Attribute.fromKeyValue(key, null)!);
    } else {
      if (sel.isCollapsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ابتدا متن را انتخاب کنید'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      _quill.formatSelection(Attribute.fromKeyValue(key, hex)!);
    }

    // جلوگیری از ادامه رنگ روی متن بعدی:
    // کرسر را به انتهای انتخاب می‌بریم و استایل pending را خنثی می‌کنیم
    final end = sel.extentOffset > sel.baseOffset
        ? sel.extentOffset
        : sel.baseOffset;
    _quill.updateSelection(
      TextSelection.collapsed(offset: end),
      ChangeSource.local,
    );
    // پاک کردن attribute فعال برای تایپ بعدی
    _quill.formatSelection(Attribute.fromKeyValue(key, null)!);

    _editorFocus.requestFocus();
    setState(() {});
  }

  void _clearAllFormatting() {
    final sel = _quill.selection;
    if (!sel.isValid || sel.isCollapsed) {
      // کل سند
      final len = _quill.document.length;
      _quill.updateSelection(
        TextSelection(baseOffset: 0, extentOffset: len - 1),
        ChangeSource.local,
      );
    }
    for (final key in [
      Attribute.bold,
      Attribute.italic,
      Attribute.underline,
      Attribute.strikeThrough,
      Attribute.inlineCode,
    ]) {
      _quill.formatSelection(Attribute.clone(key, null));
    }
    _quill.formatSelection(Attribute.fromKeyValue('color', null)!);
    _quill.formatSelection(Attribute.fromKeyValue('background', null)!);
    _editorFocus.requestFocus();
  }

  Future<void> _clearAllText() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن متن'),
        content: const Text('تمام محتوای یادداشت پاک شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('پاک کردن'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _quill.clear();
      _updateStats();
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        imageQuality: 55,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // محدودیت حجم برای وب/حافظه
      if (bytes.length > 700 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('حجم تصویر زیاد است (حداکثر ۷۰۰ کیلوبایت)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final b64 = base64Encode(bytes);
      final mime = file.mimeType ?? 'image/jpeg';
      final dataUrl = 'data:$mime;base64,$b64';
      final docLen = _quill.document.length;
      final index = _quill.selection.baseOffset.clamp(0, docLen > 0 ? docLen - 1 : 0);
      // embed با خط جدید بعد از آن تا تایپ بعدی زیر تصویر بماند
      _quill.document.insert(index, BlockEmbed.image(dataUrl));
      _quill.document.insert(index + 1, '\n');
      final caret = (index + 2).clamp(0, _quill.document.length);
      _quill.updateSelection(
        TextSelection.collapsed(offset: caret),
        ChangeSource.local,
      );
      _editorFocus.requestFocus();
      // اسکرول را به موقعیت فعلی نگه دار — پرش به بالا نکند
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_editorScrollCtrl.hasClients) return;
        // اگر لازم بود کمی پایین‌تر برو تا تصویر کامل دیده شود، نه ریست به صفر
        final pos = _editorScrollCtrl.position;
        if (pos.pixels > 0) {
          _editorScrollCtrl.jumpTo(pos.pixels.clamp(0.0, pos.maxScrollExtent));
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در درج تصویر: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleVoice() async {
    if (_recording) {
      setState(() => _recording = false);
      final metaMap = await NoteAudioService.instance.stop();
      if (metaMap == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ضبط ذخیره نشد'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final meta = jsonEncode(metaMap);
      final index =
          _quill.selection.baseOffset.clamp(0, _quill.document.length - 1);
      _quill.document.insert(index, BlockEmbed('audio', meta));
      _quill.document.insert(index + 1, '\n');
      _quill.updateSelection(
        TextSelection.collapsed(offset: index + 2),
        ChangeSource.local,
      );
      _recordSeconds = 0;
      setState(() {});
      return;
    }
    final ok = await NoteAudioService.instance.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('دسترسی میکروفون لازم است — در تنظیمات گوشی فعال کن'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    setState(() {
      _recording = true;
      _recordSeconds = 0;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_recording || !mounted) return false;
      setState(() => _recordSeconds++);
      return _recording;
    });
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('نتوانست فایل را بخواند'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final metaMap = await NoteAudioService.instance.importBytes(
        bytes,
        name: f.name,
        mime: 'audio/${f.extension ?? 'mpeg'}',
      );
      if (metaMap == null || metaMap['error'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${metaMap?['error'] ?? 'خطا در ورود فایل'}'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final meta = jsonEncode(metaMap);
      final index =
          _quill.selection.baseOffset.clamp(0, _quill.document.length - 1);
      _quill.document.insert(index, BlockEmbed('audio', meta));
      _quill.document.insert(index + 1, '\n');
      _quill.updateSelection(
        TextSelection.collapsed(offset: index + 2),
        ChangeSource.local,
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطا: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _showTableDialog({bool excel = true}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const TableInsertDialog(
        initialRows: 5,
        initialCols: 4,
        excelStyle: true,
      ),
    );
    if (result != null && result.isNotEmpty) {
      final index =
          _quill.selection.baseOffset.clamp(0, _quill.document.length - 1);
      _quill.document.insert(index, BlockEmbed('table', result));
      _quill.document.insert(index + 1, '\n');
      _quill.updateSelection(
        TextSelection.collapsed(offset: index + 2),
        ChangeSource.local,
      );
      setState(() {});
    }
  }

  Future<void> _showSymbolPicker(List<String> symbols, String title) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          builder: (_, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                child: Column(
                  children: [
                    Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'ضربه = درج | نگه‌داشتن = درج و بستن',
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.45),
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: sc,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: symbols.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () {
                      // درج بدون بستن شیت → چند ایموجی پشت‌سرهم
                      final idx = _quill.selection.baseOffset
                          .clamp(0, _quill.document.length - 1);
                      _quill.document.insert(idx, symbols[i]);
                      _quill.updateSelection(
                        TextSelection.collapsed(offset: idx + symbols[i].length),
                        ChangeSource.local,
                      );
                      setState(() {});
                    },
                    onLongPress: () => Navigator.pop(ctx, symbols[i]),
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child:
                          Text(symbols[i], style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) _insertText(selected);
  }

  Future<void> _showFormulas() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          builder: (_, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('فرمول‌های معروف',
                    style: Theme.of(ctx).textTheme.titleLarge),
              ),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: formulas.length,
                  itemBuilder: (_, i) {
                    final f = formulas[i];
                    return ListTile(
                      title: Text(f.$1),
                      subtitle: Text(
                        f.$2,
                        style: const TextStyle(fontFamily: 'serif'),
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                      ),
                      onTap: () => Navigator.pop(ctx, f.$2),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) _insertText(selected);
  }

  Future<void> _findReplace() async {
    final findCtrl = TextEditingController();
    final replaceCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('جستجو و جایگزینی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: findCtrl,
                decoration: const InputDecoration(labelText: 'جستجو')),
            const SizedBox(height: 10),
            TextField(
                controller: replaceCtrl,
                decoration: const InputDecoration(labelText: 'جایگزین')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
          TextButton(
            onPressed: () {
              final find = findCtrl.text;
              final rep = replaceCtrl.text;
              if (find.isEmpty) return;
              final plain = _quill.document.toPlainText();
              if (!plain.contains(find)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('یافت نشد')),
                );
                return;
              }
              final newPlain = plain.replaceAll(find, rep);
              _quill.document = Document()..insert(0, newPlain);
              _quill.updateSelection(
                const TextSelection.collapsed(offset: 0),
                ChangeSource.local,
              );
              Navigator.pop(ctx);
              _updateStats();
            },
            child: const Text('جایگزینی همه'),
          ),
        ],
      ),
    );
  }

  void _applyTemplate(NoteTemplate t) {
    _titleCtrl.text = t.title;
    _category = t.category;
    _color = t.color;
    _quill.document = Document()..insert(0, t.body);
    _updateStats();
    setState(() {});
  }

  Future<void> _showTemplates() async {
    final t = await showModalBottomSheet<NoteTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        // هر قالب هویت بصری جدا دارد
        final meta = <String, ({IconData icon, List<Color> gradient, String badge})>{
          'blank': (icon: Icons.notes_rounded, gradient: [const Color(0xFF64748B), const Color(0xFF94A3B8)], badge: 'ساده'),
          'meeting': (icon: Icons.groups_2_rounded, gradient: [const Color(0xFF2563EB), const Color(0xFF38BDF8)], badge: 'کاری'),
          'shopping': (icon: Icons.shopping_bag_rounded, gradient: [const Color(0xFF059669), const Color(0xFF34D399)], badge: 'روزانه'),
          'idea': (icon: Icons.lightbulb_rounded, gradient: [const Color(0xFFD97706), const Color(0xFFFBBF24)], badge: 'خلاقیت'),
          'project': (icon: Icons.flag_rounded, gradient: [const Color(0xFF7C3AED), const Color(0xFFA78BFA)], badge: 'SMART'),
          'travel': (icon: Icons.flight_takeoff_rounded, gradient: [const Color(0xFFDB2777), const Color(0xFFF472B6)], badge: 'سفر'),
          'journal': (icon: Icons.auto_stories_rounded, gradient: [const Color(0xFF4F46E5), const Color(0xFF818CF8)], badge: 'شخصی'),
          'study': (icon: Icons.menu_book_rounded, gradient: [const Color(0xFF0284C7), const Color(0xFF38BDF8)], badge: 'آموزش'),
        };

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (_, sc) => Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.dashboard_customize_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('شروع سریع',
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900)),
                            Text('یک قالب انتخاب کن تا ساختار آماده شود',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: noteTemplates.length,
                    itemBuilder: (_, i) {
                      final tpl = noteTemplates[i];
                      final m = meta[tpl.id] ?? meta['blank']!;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, tpl),
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : theme.colorScheme.outline,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: isDark
                                    ? [
                                        m.gradient[0].withOpacity(0.25),
                                        theme.colorScheme.surface,
                                      ]
                                    : [
                                        m.gradient[0].withOpacity(0.12),
                                        theme.colorScheme.surface,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: m.gradient[0].withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: m.gradient,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: m.gradient[0]
                                                  .withOpacity(0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(m.icon,
                                            color: Colors.white, size: 22),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: m.gradient[0].withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          m.badge,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: m.gradient[0],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    tpl.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tpl.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.55),
                                      height: 1.35,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (t != null) _applyTemplate(t);
  }

  void _convertCase(String mode) {
    final sel = _quill.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final text =
        _quill.document.toPlainText().substring(sel.start, sel.end);
    String result;
    switch (mode) {
      case 'upper':
        result = text.toUpperCase();
        break;
      case 'lower':
        result = text.toLowerCase();
        break;
      default:
        result = text.split(' ').map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        }).join(' ');
    }
    _quill.replaceText(sel.start, sel.end - sel.start, result,
        TextSelection.collapsed(offset: sel.start + result.length));
  }

  void _checkAll() {
    // تبدیل unchecked به checked در کل سند — ساده
    final plain = _quill.document.toPlainText();
    // در quill از format روی هر خط سخت است؛ پیام راهنما
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('برای تیک زدن، روی چک‌باکس هر آیتم کلیک کنید'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int get _readMinutes {
    if (_words == 0) return 0;
    return (_words / 200).ceil().clamp(1, 999);
  }

  String _fa(int n) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var s = n.toString();
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], fa[i]);
    }
    return s;
  }

  String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _fullscreen
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => _save(pop: true),
              ),
              title: const Text('یادداشت'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
                  tooltip: 'قالب',
                  onPressed: _showTemplates,
                ),
                IconButton(
                  icon: Icon(
                    _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: _pinned ? AppColors.brand3 : null,
                  ),
                  onPressed: () => setState(() => _pinned = !_pinned),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  onPressed: _delete,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 8),
                  child: TextButton(
                    onPressed: _saving ? null : () => _save(pop: true),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.brand3,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('ذخیره',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
      body: Column(
        children: [
          if (!_fullscreen) _buildMetaHeader(theme),
          Expanded(
            child: QuillEditor.basic(
              controller: _quill,
              focusNode: _editorFocus,
              scrollController: _editorScrollCtrl,
              config: QuillEditorConfig(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                placeholder: 'شروع به نوشتن کنید...',
                autoFocus: widget.isNew,
                expands: false,
                scrollable: true,
                embedBuilders: [
                  ImageEmbedBuilder(),
                  AudioEmbedBuilder(),
                  TableEmbedBuilder(),
                ],
              ),
            ),
          ),
          if (_recording) _buildRecordingBar(theme),
          if (!_fullscreen) ...[
            _buildStatusBar(theme),
            _buildTabBar(theme),
            _buildToolPanel(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleCtrl,
            textDirection: _directionForText(_titleCtrl.text),
            onChanged: (_) => setState(() {}),
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'عنوان یادداشت...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                ...ref.watch(categoriesProvider).categories.map((c) {
                  final sel = c == _category;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.primaryGradient : null,
                          color: sel
                              ? null
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: sel
                              ? null
                              : Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Text(c,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: sel ? Colors.white : null,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('رنگ:', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              ...noteColorKeys.map((k) {
                final c = noteColorMap[k]!;
                final sel = k == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = k),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outline,
                        width: sel ? 2.5 : 1,
                      ),
                    ),
                    child: sel
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: theme.colorScheme.outline, height: 1),
        ],
      ),
    );
  }

  Widget _buildRecordingBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.danger.withOpacity(0.12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'در حال ضبط... ${_fa(_recordSeconds)} ثانیه',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton(
            onPressed: _toggleVoice,
            child: const Text('توقف و درج'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _Stat(icon: Icons.text_fields_rounded, label: '${_fa(_words)} کلمه'),
            const SizedBox(width: 12),
            _Stat(icon: Icons.abc_rounded, label: '${_fa(_chars)} حرف'),
            const SizedBox(width: 12),
            _Stat(
                icon: Icons.schedule_rounded,
                label: '${_fa(_readMinutes)} دقیقه'),
            if (_checkTotal > 0) ...[
              const SizedBox(width: 12),
              _Stat(
                  icon: Icons.checklist_rounded,
                  label: '${_fa(_checkDone)}/${_fa(_checkTotal)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.6))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
                  tooltip: 'قبلی',
                  onPressed: () {
                    final c = _tabScrollCtrl;
                    if (!c.hasClients) return;
                    c.animateTo(
                      (c.offset + 100).clamp(0.0, c.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _tabScrollCtrl,
                    thumbVisibility: true,
                    thickness: 3,
                    radius: const Radius.circular(4),
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    child: ListView.separated(
                      controller: _tabScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      itemCount: EditorToolTab.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (_, i) {
                        final tab = EditorToolTab.values[i];
                        final sel = tab == _toolTab;
                        return GestureDetector(
                          onTap: () => setState(() => _toolTab = tab),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.brand3.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? AppColors.brand3.withOpacity(0.35)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tab.icon,
                                    size: 15,
                                    color: sel
                                        ? AppColors.brand3
                                        : theme.colorScheme.onSurface
                                            .withOpacity(0.45)),
                                const SizedBox(width: 5),
                                Text(tab.label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: sel ? AppColors.brand3 : null,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
                  tooltip: 'بعدی',
                  onPressed: () {
                    final c = _tabScrollCtrl;
                    if (!c.hasClients) return;
                    c.animateTo(
                      (c.offset - 100).clamp(0.0, c.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPanel(ThemeData theme) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.98),
        border: Border(
            top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5))),
      ),
      child: Scrollbar(
        thumbVisibility: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: _buildToolRow(theme),
        ),
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    String? tip,
    VoidCallback? onTap,
    bool active = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Material(
        color: active
            ? AppColors.brand3.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Tooltip(
            message: tip ?? '',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon,
                  size: 22,
                  color: color ??
                      (active
                          ? AppColors.brand3
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolTextBtn(String label, VoidCallback onTap, {Color? fg}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
            ),
            child: Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: fg,
                    )),
          ),
        ),
      ),
    );
  }

  Widget _buildToolRow(ThemeData theme) {
    switch (_toolTab) {
      case EditorToolTab.format:
        return Row(children: [
          _toolTextBtn('P', () => _applyAttr(Attribute.clone(Attribute.header, null))),
          _toolTextBtn('H1', () => _applyAttr(Attribute.h1)),
          _toolTextBtn('H2', () => _applyAttr(Attribute.h2)),
          _toolTextBtn('H3', () => _applyAttr(Attribute.h3)),
          _toolBtn(
              icon: Icons.format_quote_rounded,
              tip: 'نقل قول',
              onTap: () => _toggleAttr(Attribute.blockQuote)),
          _toolBtn(
              icon: Icons.code_rounded,
              tip: 'کد',
              onTap: () => _toggleAttr(Attribute.codeBlock)),
          _toolBtn(
              icon: Icons.horizontal_rule_rounded,
              tip: 'خط',
              onTap: () => _insertText('\n────────────────\n')),
        ]);

      case EditorToolTab.style:
        return Row(children: [
          _toolBtn(icon: Icons.format_bold_rounded, tip: 'ضخیم', onTap: () => _toggleAttr(Attribute.bold)),
          _toolBtn(icon: Icons.format_italic_rounded, tip: 'کج', onTap: () => _toggleAttr(Attribute.italic)),
          _toolBtn(icon: Icons.format_underlined_rounded, tip: 'زیرخط', onTap: () => _toggleAttr(Attribute.underline)),
          _toolBtn(icon: Icons.format_strikethrough_rounded, tip: 'خط‌خورده', onTap: () => _toggleAttr(Attribute.strikeThrough)),
          _toolTextBtn('x²', () => _toggleAttr(Attribute.fromKeyValue('script', 'super')!)),
          _toolTextBtn('x₂', () => _toggleAttr(Attribute.fromKeyValue('script', 'sub')!)),
        ]);

      case EditorToolTab.color:
        return Row(children: [
          ...textColors.map((c) => GestureDetector(
                onTap: () => _applyColorToSelection(_hex(c), background: false),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                ),
              )),
          _toolTextBtn('حذف', () => _applyColorToSelection(null, background: false), fg: AppColors.danger),
          const SizedBox(width: 8),
          ...highlightColors.map((c) => GestureDetector(
                onTap: () => _applyColorToSelection(_hex(c), background: true),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                ),
              )),
          _toolTextBtn('حذف‌هایلایت', () => _applyColorToSelection(null, background: true), fg: AppColors.danger),
        ]);

      case EditorToolTab.align:
        // در RTL آیکون و جهت برعکس حس می‌شد — جفت‌سازی اصلاح‌شده
        return Row(children: [
          _toolBtn(icon: Icons.format_align_right_rounded, tip: 'راست‌چین', onTap: () => _applyAttr(Attribute.leftAlignment)),
          _toolBtn(icon: Icons.format_align_center_rounded, tip: 'وسط', onTap: () => _applyAttr(Attribute.centerAlignment)),
          _toolBtn(icon: Icons.format_align_left_rounded, tip: 'چپ‌چین', onTap: () => _applyAttr(Attribute.rightAlignment)),
          _toolBtn(icon: Icons.format_align_justify_rounded, tip: 'جفت', onTap: () => _applyAttr(Attribute.justifyAlignment)),
        ]);

      case EditorToolTab.list:
        return Row(children: [
          _toolBtn(icon: Icons.format_list_bulleted_rounded, tip: 'نشانه‌دار', onTap: () => _toggleAttr(Attribute.ul)),
          _toolBtn(icon: Icons.format_list_numbered_rounded, tip: 'شماره‌دار', onTap: () => _toggleAttr(Attribute.ol)),
          _toolBtn(icon: Icons.checklist_rounded, tip: 'چک‌لیست', onTap: () => _toggleAttr(Attribute.unchecked)),
          _toolBtn(icon: Icons.format_indent_increase_rounded, tip: 'تورفتگی+', onTap: () => _applyAttr(Attribute.indentL1)),
          _toolBtn(icon: Icons.format_indent_decrease_rounded, tip: 'تورفتگی-', onTap: () => _applyAttr(Attribute.fromKeyValue('indent', 0)!)),
        ]);

      case EditorToolTab.insert:
        return Row(children: [
          _toolBtn(
            icon: Icons.link_rounded,
            tip: 'لینک',
            onTap: () async {
              final sel = _quill.selection;
              if (!sel.isValid || sel.isCollapsed) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('اول متن را انتخاب کنید، بعد لینک بگذارید'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }
              final ctrl = TextEditingController(text: 'https://');
              final url = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('لینک روی متن انتخاب‌شده'),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      labelText: 'آدرس',
                      hintText: 'https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
                    TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('اعمال')),
                  ],
                ),
              );
              if (url != null && url.isNotEmpty) {
                _quill.formatSelection(LinkAttribute(url));
                _editorFocus.requestFocus();
              }
            },
          ),
          _toolBtn(icon: Icons.image_outlined, tip: 'تصویر', onTap: _pickImage),
          _toolBtn(
            icon: _recording ? Icons.stop_circle_outlined : Icons.mic_rounded,
            tip: _recording ? 'توقف ضبط' : 'ضبط صدا',
            color: _recording ? AppColors.danger : null,
            onTap: _toggleVoice,
          ),
          _toolBtn(
            icon: Icons.library_music_outlined,
            tip: 'آپلود فایل صوتی',
            onTap: _pickAudioFile,
          ),
          _toolBtn(icon: Icons.emoji_emotions_outlined, tip: 'ایموجی', onTap: () => _showSymbolPicker(emojis, 'ایموجی')),
        ]);

      case EditorToolTab.table:
        return Row(children: [
          _toolBtn(icon: Icons.grid_on_rounded, tip: 'جدول اکسل', onTap: () => _showTableDialog(excel: true)),
        ]);

      case EditorToolTab.tools:
        return Row(children: [
          _toolBtn(icon: Icons.undo_rounded, tip: 'واگرد', onTap: () => _quill.undo()),
          _toolBtn(icon: Icons.redo_rounded, tip: 'ازنو', onTap: () => _quill.redo()),
          _toolBtn(icon: Icons.format_clear_rounded, tip: 'پاک‌سازی قالب', onTap: _clearAllFormatting),
          _toolBtn(icon: Icons.delete_sweep_rounded, tip: 'پاک کردن متن', color: AppColors.danger, onTap: _clearAllText),
          _toolBtn(icon: Icons.calendar_today_rounded, tip: 'تاریخ شمسی', onTap: () => _insertText(Jalali.nowString(withMonthName: true))),
          _toolBtn(icon: Icons.functions_rounded, tip: 'فرمول', onTap: _showFormulas),
          _toolBtn(icon: Icons.find_replace_rounded, tip: 'جستجو', onTap: _findReplace),
          _toolBtn(
            icon: _fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            tip: 'تمام‌صفحه',
            onTap: () => setState(() => _fullscreen = !_fullscreen),
          ),
        ]);
    }
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.brand3),
        const SizedBox(width: 3),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                )),
      ],
    );
  }
}
