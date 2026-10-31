import 'package:flutter/material.dart';

import 'models.dart';

// The default colors also remain available for the native launch frame.
class AppPalette {
  const AppPalette._();
  static const canvas = Color(0xFFE8E8E1);
  static const canvasRaised = Color(0xFFF0EFE9);
  static const field = Color(0xFFE1E1DA);
  static const parentNote = Color(0xFFCCD1C7);
  static const parentNotePressed = Color(0xFFC3C9BE);
  static const childNote = Color(0xFFD9DCD5);
  static const childNoteDone = Color(0xFFD0D1CC);
  static const completedNote = Color(0xFFCDCEC8);
  static const completionFill = Color(0xFFB8C9B9);
  static const ink = Color(0xFF18201B);
  static const inkSoft = Color(0xFF343D37);
  static const muted = Color(0xFF4F5A53);
  static const mutedLight = Color(0xFF6F7771);
  static const rule = Color(0xFFC5C8C0);
  static const pine = Color(0xFF1D4A3C);
  static const pineInk = Color(0xFFF1F0E9);
  static const warning = Color(0xFFC9732B);
  static const missed = Color(0xFFC94F45);
  static const statusSage = Color(0xFF718C7B);
}

@immutable
class DailyColors extends ThemeExtension<DailyColors> {
  const DailyColors._(this._values);
  final Map<String, Color> _values;

  static const sage = DailyColors._({
    'canvas': AppPalette.canvas,
    'canvasRaised': AppPalette.canvasRaised,
    'field': AppPalette.field,
    'parentNote': AppPalette.parentNote,
    'parentNotePressed': AppPalette.parentNotePressed,
    'childNote': AppPalette.childNote,
    'childNoteDone': AppPalette.childNoteDone,
    'completedNote': AppPalette.completedNote,
    'completionFill': AppPalette.completionFill,
    'ink': AppPalette.ink,
    'inkSoft': AppPalette.inkSoft,
    'muted': AppPalette.muted,
    'mutedLight': AppPalette.mutedLight,
    'rule': AppPalette.rule,
    'pine': AppPalette.pine,
    'pineInk': AppPalette.pineInk,
    'warning': AppPalette.warning,
    'missed': AppPalette.missed,
    'statusSage': AppPalette.statusSage,
  });

  factory DailyColors.forTheme(DailyThemeColor theme) {
    if (theme == DailyThemeColor.sage) return sage;
    final overrides = switch (theme) {
      DailyThemeColor.blue => const {
        'canvas': Color(0xFFE5E9EB),
        'canvasRaised': Color(0xFFF0F3F4),
        'field': Color(0xFFDCE3E7),
        'parentNote': Color(0xFFCCD4D8),
        'parentNotePressed': Color(0xFFC1CCD2),
        'childNote': Color(0xFFD7E0E5),
        'childNoteDone': Color(0xFFD0D7DA),
        'completedNote': Color(0xFFCDD4D7),
        'completionFill': Color(0xFFB9CCD8),
        'ink': Color(0xFF1C252D),
        'inkSoft': Color(0xFF35434E),
        'muted': Color(0xFF50606D),
        'mutedLight': Color(0xFF6C7A85),
        'rule': Color(0xFFC3CED5),
        'pine': Color(0xFF2C526D),
        'pineInk': Color(0xFFF3F5F6),
        'statusSage': Color(0xFF708FA4),
      },
      DailyThemeColor.apricot => const {
        'canvas': Color(0xFFEEE6DC),
        'canvasRaised': Color(0xFFF7F0E8),
        'field': Color(0xFFE7DCCF),
        'parentNote': Color(0xFFDCD0C3),
        'parentNotePressed': Color(0xFFD4C5B6),
        'childNote': Color(0xFFE9D8C8),
        'childNoteDone': Color(0xFFDFD3C6),
        'completedNote': Color(0xFFDDD1C4),
        'completionFill': Color(0xFFE1C4A7),
        'ink': Color(0xFF30251D),
        'inkSoft': Color(0xFF514133),
        'muted': Color(0xFF6B5948),
        'mutedLight': Color(0xFF86725F),
        'rule': Color(0xFFD7C8B8),
        'pine': Color(0xFF785139),
        'pineInk': Color(0xFFFBF3E9),
        'statusSage': Color(0xFFA58261),
      },
      DailyThemeColor.lavender => const {
        'canvas': Color(0xFFE9E6ED),
        'canvasRaised': Color(0xFFF3F0F6),
        'field': Color(0xFFE1DBE8),
        'parentNote': Color(0xFFD3CDD9),
        'parentNotePressed': Color(0xFFC9C0D1),
        'childNote': Color(0xFFDED4E7),
        'childNoteDone': Color(0xFFD7D0DE),
        'completedNote': Color(0xFFD4CEDA),
        'completionFill': Color(0xFFCABBDD),
        'ink': Color(0xFF292330),
        'inkSoft': Color(0xFF463B51),
        'muted': Color(0xFF62546D),
        'mutedLight': Color(0xFF7E7088),
        'rule': Color(0xFFCEC5D6),
        'pine': Color(0xFF5F4676),
        'pineInk': Color(0xFFF8F2FC),
        'statusSage': Color(0xFF9279A7),
      },
      DailyThemeColor.sage => const <String, Color>{},
    };
    return DailyColors._({...sage._values, ...overrides});
  }

  Color get canvas => _values['canvas']!;
  Color get canvasRaised => _values['canvasRaised']!;
  Color get field => _values['field']!;
  Color get parentNote => _values['parentNote']!;
  Color get parentNotePressed => _values['parentNotePressed']!;
  Color get childNote => _values['childNote']!;
  Color get childNoteDone => _values['childNoteDone']!;
  Color get completedNote => _values['completedNote']!;
  Color get completionFill => _values['completionFill']!;
  Color get ink => _values['ink']!;
  Color get inkSoft => _values['inkSoft']!;
  Color get muted => _values['muted']!;
  Color get mutedLight => _values['mutedLight']!;
  Color get rule => _values['rule']!;
  Color get pine => _values['pine']!;
  Color get pineInk => _values['pineInk']!;
  Color get warning => _values['warning']!;
  Color get missed => _values['missed']!;
  Color get statusSage => _values['statusSage']!;

  @override
  DailyColors copyWith({Map<String, Color>? values}) =>
      DailyColors._({..._values, ...?values});

  @override
  DailyColors lerp(covariant DailyColors? other, double t) => other == null
      ? this
      : DailyColors._({
          for (final key in _values.keys)
            key: Color.lerp(_values[key], other._values[key], t)!,
        });
}

extension DailyColorContext on BuildContext {
  DailyColors get palette =>
      Theme.of(this).extension<DailyColors>() ?? DailyColors.sage;
}

class DailyThemeController extends ChangeNotifier {
  DailyThemeController(this.store);
  final DailyStore store;
  DailyThemeColor color = DailyThemeColor.sage;
  DailyThemeColor _savedColor = DailyThemeColor.sage;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _pendingWrite = Future<void>.value();
  Future<void>? _loading;

  Future<void> load() => _loading ??= _readSavedColor();

  Future<void> _readSavedColor() async {
    final revision = _revision;
    try {
      final saved = await store.loadThemeColor();
      if (_disposed) return;
      _savedColor = saved;
      if (revision != _revision || color == saved) return;
      color = saved;
      notifyListeners();
    } on Object {
      /* Keep the default if preferences cannot be read. */
    }
  }

  Future<bool> select(DailyThemeColor selected) async {
    if (color == selected) return true;
    final initialLoad = load();
    final revision = ++_revision;
    color = selected;
    notifyListeners();
    final write = _pendingWrite.then((_) async {
      await initialLoad;
      await store.saveThemeColor(selected);
      _savedColor = selected;
    });
    _pendingWrite = write.catchError((Object _) {});
    try {
      await write;
      return true;
    } on Object {
      if (!_disposed && revision == _revision) {
        color = _savedColor;
        notifyListeners();
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class DailyThemeScope extends InheritedNotifier<DailyThemeController> {
  const DailyThemeScope({
    required DailyThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static DailyThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DailyThemeScope>()?.notifier;
}
