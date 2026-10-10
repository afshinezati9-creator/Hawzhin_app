import 'package:equatable/equatable.dart';

/// انواع پس‌زمینه سطح — نام‌ها یکتا، ظاهر متنوع
enum SurfaceType {
  wall('wall', 'دیوار ملایم'),
  desk('desk', 'میز بلوط'),
  board('board', 'تخته مات'),
  cork('cork', 'چوب‌پنبه'),
  door('door', 'چوب گردو'),
  dusk('dusk', 'غروب'),
  ocean('ocean', 'اقیانوس'),
  forest('forest', 'جنگل');

  const SurfaceType(this.id, this.label);
  final String id;
  final String label;

  static SurfaceType fromId(String? id) {
    // سازگاری با داده‌های قدیمی
    switch (id) {
      case 'fridge':
      case 'mirror':
        return SurfaceType.board;
      case 'car':
        return SurfaceType.ocean;
      case 'cabinet':
        return SurfaceType.door;
      default:
        break;
    }
    return SurfaceType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => SurfaceType.wall,
    );
  }
}

class StickerTask extends Equatable {
  final String id;
  final String text;
  final bool done;

  const StickerTask({
    required this.id,
    required this.text,
    this.done = false,
  });

  StickerTask copyWith({String? id, String? text, bool? done}) {
    return StickerTask(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'done': done,
      };

  factory StickerTask.fromMap(Map<String, dynamic> m) => StickerTask(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        done: m['done'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, text, done];
}

class StickerNote extends Equatable {
  final String id;
  final String title;
  final String color; // yellow, pink, ...
  final String icon; // check, cart, ...
  final List<StickerTask> tasks;
  final bool archived;
  final String archiveNote;
  final DateTime? archivedAt;
  final DateTime? dueDate;

  const StickerNote({
    required this.id,
    required this.title,
    this.color = 'yellow',
    this.icon = 'check',
    this.tasks = const [],
    this.archived = false,
    this.archiveNote = '',
    this.archivedAt,
    this.dueDate,
  });

  int get doneCount => tasks.where((t) => t.done).length;
  int get totalCount => tasks.length;
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  StickerNote copyWith({
    String? id,
    String? title,
    String? color,
    String? icon,
    List<StickerTask>? tasks,
    bool? archived,
    String? archiveNote,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) {
    return StickerNote(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      tasks: tasks ?? this.tasks,
      archived: archived ?? this.archived,
      archiveNote: archiveNote ?? this.archiveNote,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'color': color,
        'icon': icon,
        'tasks': tasks.map((e) => e.toMap()).toList(),
        'archived': archived,
        'archiveNote': archiveNote,
        'archivedAt': archivedAt?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
      };

  factory StickerNote.fromMap(Map<String, dynamic> m) {
    final rawTasks = m['tasks'] as List<dynamic>? ?? [];
    return StickerNote(
      id: m['id'] as String? ?? '',
      title: m['title'] as String? ?? '',
      color: m['color'] as String? ?? 'yellow',
      icon: m['icon'] as String? ?? 'check',
      tasks: rawTasks
          .map((e) => StickerTask.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      archived: m['archived'] as bool? ?? false,
      archiveNote: m['archiveNote'] as String? ?? '',
      archivedAt: DateTime.tryParse(m['archivedAt'] as String? ?? ''),
      dueDate: DateTime.tryParse(m['dueDate'] as String? ?? ''),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, color, icon, tasks, archived, archiveNote, archivedAt, dueDate];
}

class StickerSurface extends Equatable {
  final String id;
  final String name;
  final SurfaceType type;
  final List<StickerNote> notes;
  final bool archived;
  final String archiveNote;
  final DateTime? archivedAt;

  const StickerSurface({
    required this.id,
    required this.name,
    required this.type,
    this.notes = const [],
    this.archived = false,
    this.archiveNote = '',
    this.archivedAt,
  });

  List<StickerNote> get activeNotes =>
      notes.where((n) => !n.archived).toList();

  StickerSurface copyWith({
    String? id,
    String? name,
    SurfaceType? type,
    List<StickerNote>? notes,
    bool? archived,
    String? archiveNote,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return StickerSurface(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      archived: archived ?? this.archived,
      archiveNote: archiveNote ?? this.archiveNote,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.id,
        'notes': notes.map((e) => e.toMap()).toList(),
        'archived': archived,
        'archiveNote': archiveNote,
        'archivedAt': archivedAt?.toIso8601String(),
      };

  factory StickerSurface.fromMap(Map<String, dynamic> m) {
    final rawNotes = m['notes'] as List<dynamic>? ?? [];
    return StickerSurface(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      type: SurfaceType.fromId(m['type'] as String?),
      notes: rawNotes
          .map((e) => StickerNote.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      archived: m['archived'] as bool? ?? false,
      archiveNote: m['archiveNote'] as String? ?? '',
      archivedAt: DateTime.tryParse(m['archivedAt'] as String? ?? ''),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, type, notes, archived, archiveNote, archivedAt];
}

/// رنگ‌های برچسب
const stickerNoteColors = <String, int>{
  'yellow': 0xFFFEF3C7,
  'pink': 0xFFFCE7F3,
  'mint': 0xFFD1FAE5,
  'sky': 0xFFDBEAFE,
  'lilac': 0xFFEDE9FE,
  'peach': 0xFFFFEDD5,
  'coral': 0xFFFEE2E2,
  'lime': 0xFFECFCCB,
  'rose': 0xFFFFE4E6,
};

const stickerIcons = <String>[
  'check',
  'cart',
  'book',
  'calendar',
  'star',
  'heart',
  'briefcase',
  'coffee',
  'home',
  'plane',
  'music',
  'code',
  'brush',
  'dumbbell',
  'lock',
];

const stickerIconLabels = <String, String>{
  'check': 'کار',
  'cart': 'خرید',
  'book': 'مطالعه',
  'calendar': 'تقویم',
  'star': 'مهم',
  'heart': 'علاقه',
  'briefcase': 'کاری',
  'coffee': 'روزانه',
  'home': 'خانه',
  'plane': 'سفر',
  'music': 'موسیقی',
  'code': 'کد',
  'brush': 'هنر',
  'dumbbell': 'ورزش',
  'lock': 'خصوصی',
};

