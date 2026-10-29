// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · route: custom (tuned) · vibe: mineral, quiet, botanical, precise
// Hallmark · structure: calendar-first index + in-place indented dose rail
// Hallmark · axes: light / editorial-serif / chromatic-sage · studied: yes
// Hallmark · audit: contrast pass · mobile pass · tokens pass · states pass

import 'dart:async';
import 'dart:ui' show PathMetric;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'services/notification_service.dart';

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

class AppRadii {
  const AppRadii._();

  static const medium = 16.0;
  static const large = 20.0;
  static const pill = 28.0;
}

String quantityLabel(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String? inventoryStatusLabel(ReminderItem item) {
  final remaining = item.remainingQuantity;
  if (remaining == null) return null;
  if (remaining <= 0) {
    return '库存不足 · ${quantityLabel(remaining)} ${item.stockUnit}';
  }
  return '剩余 ${quantityLabel(remaining)} ${item.stockUnit}';
}

String? expiryStatusLabel(ReminderItem item, DateTime today) {
  final expiry = item.expiryDate;
  if (expiry == null) return null;
  if (dateOnly(expiry).isBefore(dateOnly(today))) return '已过有效期';
  return '有效期至 ${yearDate(expiry)}';
}

Duration appMotion(BuildContext context, int milliseconds) {
  return MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}

class _MotionAnimatedSize extends StatelessWidget {
  const _MotionAnimatedSize({
    required this.milliseconds,
    required this.child,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
  });

  final int milliseconds;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: Duration(milliseconds: milliseconds),
      curve: curve,
      alignment: alignment,
      child: child,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppPalette.pine,
      onPrimary: AppPalette.pineInk,
      secondary: AppPalette.parentNote,
      onSecondary: AppPalette.ink,
      surface: AppPalette.canvas,
      onSurface: AppPalette.ink,
      error: AppPalette.missed,
      onError: AppPalette.pineInk,
      outline: AppPalette.rule,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.canvas,
      fontFamily: 'Noto Sans SC',
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppPalette.ink,
          fontSize: 43,
          height: 1.04,
          fontWeight: FontWeight.w500,
          letterSpacing: -1.5,
        ),
        headlineLarge: TextStyle(
          color: AppPalette.ink,
          fontSize: 31,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: AppPalette.ink,
          fontSize: 23,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        titleLarge: TextStyle(
          color: AppPalette.ink,
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppPalette.ink,
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppPalette.ink,
          fontSize: 16,
          height: 1.42,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: AppPalette.inkSoft,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: AppPalette.muted,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: AppPalette.ink,
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.rule,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.field,
        hintStyle: TextStyle(color: AppPalette.mutedLight),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppPalette.rule),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppPalette.rule),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppPalette.pine),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppPalette.missed),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppPalette.missed),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppPalette.ink,
        contentTextStyle: TextStyle(color: AppPalette.pineInk),
        actionTextColor: Color(0xFFC9DDD4),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          elevation: 2,
          shadowColor: AppPalette.pine.withValues(alpha: 0.22),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.pine,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class DailyApp extends StatelessWidget {
  const DailyApp({
    required this.store,
    required this.scheduler,
    required this.refreshSignal,
    super.key,
  });

  final DailyStore store;
  final ReminderScheduler scheduler;
  final AppRefreshSignal refreshSignal;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: DailyShell(
        store: store,
        scheduler: scheduler,
        refreshSignal: refreshSignal,
      ),
    );
  }
}

class DailyShell extends StatefulWidget {
  const DailyShell({
    required this.store,
    required this.scheduler,
    required this.refreshSignal,
    super.key,
  });

  final DailyStore store;
  final ReminderScheduler scheduler;
  final AppRefreshSignal refreshSignal;

  @override
  State<DailyShell> createState() => _DailyShellState();
}

class _DailyShellState extends State<DailyShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _revision = 0;
  StreamSubscription<void>? _refreshSubscription;
  bool _exactAlarmHintShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSubscription = widget.refreshSignal.stream.listen(
      (_) => _refresh(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      unawaited(_syncNotifications());
    }
  }

  void _refresh() {
    if (mounted) setState(() => _revision++);
  }

  Future<void> _syncNotifications() async {
    final items = await widget.store.loadItems();
    await widget.scheduler.sync(items);
  }

  Future<void> _openEditor([ReminderItem? item]) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ItemEditorPage(store: widget.store, item: item),
      ),
    );
    if (saved ?? false) {
      _refresh();
      await _syncNotifications();
      await _showExactAlarmHintIfNeeded();
    }
  }

  Future<void> _openSettings() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          store: widget.store,
          scheduler: widget.scheduler,
          revision: _revision,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _showExactAlarmHintIfNeeded() async {
    if (_exactAlarmHintShown || !mounted) return;
    final health = await widget.scheduler.health();
    if (health.exactAlarmAllowed || !mounted) return;
    _exactAlarmHintShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('请开启“闹钟和提醒”，事项才能按设定时间准时弹出'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '开启',
          onPressed: () => unawaited(_enableExactAlarms()),
        ),
      ),
    );
  }

  Future<void> _enableExactAlarms() async {
    final allowed = await widget.scheduler.requestExactAlarmPermission();
    if (allowed) await _syncNotifications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(allowed ? '准时提醒已开启' : '未开启准时提醒，系统可能延迟事项通知'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CalendarPage(
        store: widget.store,
        revision: _revision,
        onAdd: _openEditor,
        onOpenSettings: _openSettings,
        onDataChanged: _refresh,
      ),
      ItemsPage(
        store: widget.store,
        scheduler: widget.scheduler,
        revision: _revision,
        onAdd: _openEditor,
        onEdit: _openEditor,
        onOpenSettings: _openSettings,
        onDataChanged: _refresh,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          ScaffoldMessenger.of(context).clearSnackBars();
          setState(() {
            _selectedIndex = index;
            _revision++;
          });
        },
      ),
    );
  }
}

IconData iconForKey(String key) => switch (key) {
  'vitamin' => Icons.eco_outlined,
  'exercise' => Icons.fitness_center_rounded,
  'eye' => Icons.visibility_outlined,
  'water' => Icons.water_drop_outlined,
  _ => Icons.medication_outlined,
};

String shortDate(DateTime date) => '${date.month} 月 ${date.day} 日';
String yearDate(DateTime date) => '${date.year}年${date.month}月${date.day}日';

String fullDate(DateTime date) {
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '${date.month} 月 ${date.day} 日 · ${weekdays[date.weekday - 1]}';
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    required this.store,
    required this.revision,
    required this.onAdd,
    required this.onOpenSettings,
    required this.onDataChanged,
    super.key,
  });

  final DailyStore store;
  final int revision;
  final VoidCallback onAdd;
  final VoidCallback onOpenSettings;
  final VoidCallback onDataChanged;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  List<ReminderItem> _items = const [];
  Set<String> _completionKeys = const {};
  final Set<int> _expandedItemIds = <int>{};
  final Set<String> _completionWrites = <String>{};
  final Map<String, DateTime> _completionBlockedUntil = <String, DateTime>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _selectedDate = today;
    _visibleMonth = DateTime(today.year, today.month);
    _load();
  }

  @override
  void didUpdateWidget(CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) _load();
  }

  DateTime get _gridStart {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month);
    return first.subtract(Duration(days: first.weekday % 7));
  }

  Future<void> _load() async {
    final start = _gridStart;
    final results = await Future.wait<Object>([
      widget.store.loadItems(),
      widget.store.loadCompletionKeys(
        start,
        start.add(const Duration(days: 41)),
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _items = results[0] as List<ReminderItem>;
      _completionKeys = results[1] as Set<String>;
      _expandedItemIds.removeWhere(
        (id) => !_items.any((item) => item.id == id),
      );
      _loading = false;
    });
  }

  List<DayTaskGroup> get _groups {
    final groups = _items
        .where((item) => item.isScheduledOn(_selectedDate))
        .map(
          (item) => DayTaskGroup(
            item: item,
            date: _selectedDate,
            completedKeys: _completionKeys,
          ),
        )
        .toList(growable: false);
    return <DayTaskGroup>[
      ...groups.where((group) => !group.allCompleted),
      ...groups.where((group) => group.allCompleted),
    ];
  }

  Future<void> _toggleCompletion(DayTaskGroup group, ReminderTime time) async {
    await _setCompletionValue(group, time, completed: null);
  }

  Future<void> _setCompletionValue(
    DayTaskGroup group,
    ReminderTime time, {
    required bool? completed,
    bool showUndo = true,
    bool bypassDebounce = false,
  }) async {
    final itemId = group.item.id;
    final timeId = time.id;
    if (itemId == null || timeId == null) return;
    final occurrenceDate = dateOnly(_selectedDate);
    final key = completionKey(itemId, timeId, occurrenceDate);
    final now = DateTime.now();
    if (_completionWrites.contains(key)) return;
    final blockedUntil = _completionBlockedUntil[key];
    if (!bypassDebounce && blockedUntil != null && blockedUntil.isAfter(now)) {
      return;
    }
    final nextValue = completed ?? !_completionKeys.contains(key);
    _completionWrites.add(key);
    _completionBlockedUntil[key] = now.add(const Duration(milliseconds: 550));
    setState(() {
      final nextKeys = Set<String>.from(_completionKeys);
      if (nextValue) {
        nextKeys.add(key);
      } else {
        nextKeys.remove(key);
      }
      _completionKeys = nextKeys;
    });
    try {
      await widget.store.setCompletion(
        itemId: itemId,
        reminderTimeId: timeId,
        date: occurrenceDate,
        completed: nextValue,
      );
      widget.onDataChanged();
      _completionWrites.remove(key);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      if (nextValue && showUndo) {
        final sequence = time.sortOrder + 1;
        final suffix = group.item.times.length > 1 ? ' · 第 $sequence 次' : '';
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            persist: false,
            content: Text('已完成“${group.item.title}$suffix”'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => _setCompletionValue(
                group,
                time,
                completed: false,
                showUndo: false,
                bypassDebounce: true,
              ),
            ),
          ),
        );
      } else if (!nextValue && showUndo) {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('已撤销完成'),
          ),
        );
      }
    } on Object {
      _completionWrites.remove(key);
      if (!mounted) return;
      setState(() {
        final rollback = Set<String>.from(_completionKeys);
        if (nextValue) {
          rollback.remove(key);
        } else {
          rollback.add(key);
        }
        _completionKeys = rollback;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未能保存完成状态，请再试一次')));
    }
  }

  Color? _statusFor(DateTime date) {
    var total = 0;
    var completed = 0;
    for (final item in _items.where((entry) => entry.isScheduledOn(date))) {
      for (final time in item.times) {
        total++;
        final itemId = item.id;
        final timeId = time.id;
        if (itemId != null &&
            timeId != null &&
            _completionKeys.contains(completionKey(itemId, timeId, date))) {
          completed++;
        }
      }
    }
    return switch (dayRecordStatus(
      date: date,
      today: DateTime.now(),
      completed: completed,
      total: total,
    )) {
      DayRecordStatus.none => null,
      DayRecordStatus.pending => AppPalette.statusSage,
      DayRecordStatus.partial => AppPalette.warning,
      DayRecordStatus.complete => AppPalette.pine,
      DayRecordStatus.missed => AppPalette.missed,
    };
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      if (_selectedDate.year != _visibleMonth.year ||
          _selectedDate.month != _visibleMonth.month) {
        _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final total = groups.fold<int>(
      0,
      (sum, group) => sum + group.item.times.length,
    );
    final completed = groups.fold<int>(
      0,
      (sum, group) => sum + group.completedCount,
    );
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppPalette.pine,
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey<String>('calendar-page'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            CalendarHeader(
              visibleMonth: _visibleMonth,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
              onAdd: widget.onAdd,
              onOpenSettings: widget.onOpenSettings,
            ),
            const SizedBox(height: 18),
            CalendarMonth(
              visibleMonth: _visibleMonth,
              selectedDate: _selectedDate,
              statusFor: _statusFor,
              onSelected: (date) {
                setState(() => _selectedDate = dateOnly(date));
              },
            ),
            const SizedBox(height: 18),
            DailySummary(
              date: _selectedDate,
              completed: completed,
              total: total,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const TaskListSkeleton()
            else if (groups.isEmpty)
              EmptyDayState(onAdd: widget.onAdd)
            else
              _AnimatedOrderColumn(
                key: ValueKey<String>('day-order-${dayKey(_selectedDate)}'),
                gap: 10,
                estimatedHeight: 82,
                entries: [
                  for (final group in groups)
                    _AnimatedOrderEntry(
                      id: group.item.id!,
                      child: TaskGroupView(
                        key: ValueKey<String>('group-${group.item.id}'),
                        group: group,
                        expanded:
                            group.item.times.length > 1 &&
                            _expandedItemIds.contains(group.item.id),
                        onToggleExpanded: group.item.times.length > 1
                            ? () => setState(() {
                                final itemId = group.item.id!;
                                if (!_expandedItemIds.remove(itemId)) {
                                  _expandedItemIds.add(itemId);
                                }
                              })
                            : null,
                        onToggleCompletion: (time) =>
                            _toggleCompletion(group, time),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedOrderEntry {
  const _AnimatedOrderEntry({required this.id, required this.child});

  final Object id;
  final Widget child;
}

class _AnimatedOrderColumn extends StatefulWidget {
  const _AnimatedOrderColumn({
    required this.entries,
    required this.estimatedHeight,
    this.gap = 0,
    super.key,
  });

  final List<_AnimatedOrderEntry> entries;
  final double estimatedHeight;
  final double gap;

  @override
  State<_AnimatedOrderColumn> createState() => _AnimatedOrderColumnState();
}

class _AnimatedOrderColumnState extends State<_AnimatedOrderColumn> {
  final Map<Object, double> _heights = <Object, double>{};

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    final duration = appMotion(context, 320);
    final positions = <Object, double>{};
    var totalHeight = 0.0;
    for (final entry in widget.entries) {
      positions[entry.id] = totalHeight;
      totalHeight +=
          (_heights[entry.id] ?? widget.estimatedHeight) + widget.gap;
    }
    totalHeight -= widget.gap;

    return _MotionAnimatedSize(
      milliseconds: 320,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: totalHeight,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final entry in widget.entries)
              AnimatedPositioned(
                key: ValueKey<Object>(entry.id),
                duration: duration,
                curve: Curves.easeInOutCubic,
                top: positions[entry.id]!,
                left: 0,
                right: 0,
                child: _MeasureSize(
                  onChange: (size) {
                    if (!mounted ||
                        !widget.entries.any((item) => item.id == entry.id)) {
                      return;
                    }
                    if (_heights[entry.id] == size.height) return;
                    setState(() => _heights[entry.id] = size.height);
                  },
                  child: entry.child,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _previousSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_previousSize == size) return;
    _previousSize = size;
    final reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(reportedSize));
  }
}

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    required this.visibleMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onAdd,
    required this.onOpenSettings,
    super.key,
  });

  final DateTime visibleMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAdd;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontFamily: 'serif',
                  fontStyle: FontStyle.normal,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${visibleMonth.year} 年 ${visibleMonth.month} 月',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _CompactMonthButton(
                    icon: Icons.chevron_left_rounded,
                    label: '上个月',
                    onPressed: onPrevious,
                  ),
                  _CompactMonthButton(
                    icon: Icons.chevron_right_rounded,
                    label: '下个月',
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoftIconButton(
              key: const Key('add-item-button'),
              icon: Icons.add_rounded,
              tooltip: '新建事项',
              onPressed: onAdd,
            ),
            const SizedBox(width: 8),
            SoftIconButton(
              key: const Key('calendar-settings-button'),
              icon: Icons.settings_rounded,
              tooltip: '设置',
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactMonthButton extends StatelessWidget {
  const _CompactMonthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class CalendarMonth extends StatelessWidget {
  const CalendarMonth({
    required this.visibleMonth,
    required this.selectedDate,
    required this.statusFor,
    required this.onSelected,
    super.key,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Color? Function(DateTime) statusFor;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    return Column(
      children: [
        Row(
          children: labels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 52,
          ),
          itemBuilder: (context, index) {
            final date = gridStart.add(Duration(days: index));
            return CalendarDayCell(
              date: date,
              inMonth: date.month == visibleMonth.month,
              selected: dayKey(date) == dayKey(selectedDate),
              statusColor: statusFor(date),
              onTap: () => onSelected(date),
            );
          },
        ),
      ],
    );
  }
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.statusColor,
    required this.onTap,
    super.key,
  });

  final DateTime date;
  final bool inMonth;
  final bool selected;
  final Color? statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${date.month} 月 ${date.day} 日',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: appMotion(context, 120),
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppPalette.pine : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: selected
                      ? AppPalette.pineInk
                      : inMonth
                      ? AppPalette.ink
                      : AppPalette.mutedLight,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              height: 7,
              child: statusColor == null
                  ? null
                  : Center(
                      child: Container(
                        key: ValueKey<String>(
                          'calendar-status-${dayKey(date)}',
                        ),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailySummary extends StatelessWidget {
  const DailySummary({
    required this.date,
    required this.completed,
    required this.total,
    super.key,
  });

  final DateTime date;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final status = dayRecordStatus(
      date: date,
      today: DateTime.now(),
      completed: completed,
      total: total,
    );
    final summary = switch (status) {
      DayRecordStatus.none => total == 0 ? '暂无事项' : '计划 $total 次',
      DayRecordStatus.pending => '待记录 $total 次',
      DayRecordStatus.partial => '$completed / $total 已记录',
      DayRecordStatus.complete => '$completed / $total 已完成',
      DayRecordStatus.missed => '遗漏 ${total - completed} 次',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.canvasRaised,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fullDate(date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class TaskGroupView extends StatelessWidget {
  const TaskGroupView({
    required this.group,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggleCompletion,
    super.key,
  });

  final DayTaskGroup group;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final ValueChanged<ReminderTime> onToggleCompletion;

  String get _periodLabel {
    final item = group.item;
    final end = item.endDate;
    if (end == null) return '${item.scheduleLabel} · 长期';
    return '${item.scheduleLabel} · ${shortDate(item.startDate)}–${shortDate(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final isMultiple = group.item.times.length > 1;
    final inventoryLabel = inventoryStatusLabel(group.item);
    final expiryLabel = expiryStatusLabel(group.item, group.date);
    final onlyTime = isMultiple ? null : group.item.times.single;
    final singleCompleted = onlyTime != null && group.isCompleted(onlyTime);
    final parentCompleted = isMultiple ? group.allCompleted : singleCompleted;

    return Column(
      children: [
        Material(
          color: parentCompleted
              ? AppPalette.completedNote
              : AppPalette.parentNote,
          animationDuration: appMotion(context, 240),
          borderRadius: BorderRadius.circular(AppRadii.large),
          elevation: parentCompleted ? 0 : 1,
          shadowColor: AppPalette.pine.withValues(alpha: 0.13),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('task-${group.item.id}'),
            onTap: isMultiple ? onToggleExpanded : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
                child: Row(
                  children: [
                    Icon(
                      iconForKey(group.item.iconKey),
                      color: parentCompleted
                          ? AppPalette.muted
                          : AppPalette.pine,
                      size: 27,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            group.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: parentCompleted
                                      ? AppPalette.muted
                                      : AppPalette.ink,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _periodLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (inventoryLabel != null ||
                              expiryLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                inventoryLabel,
                                expiryLabel,
                              ].whereType<String>().join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color:
                                        (group.item.remainingQuantity ?? 1) <=
                                                0 ||
                                            (group.item.expiryDate != null &&
                                                dateOnly(
                                                  group.item.expiryDate!,
                                                ).isBefore(
                                                  dateOnly(group.date),
                                                ))
                                        ? AppPalette.missed
                                        : AppPalette.pine,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isMultiple) ...[
                      Text(
                        '${group.completedCount} / ${group.item.times.length}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: parentCompleted
                              ? AppPalette.muted
                              : AppPalette.ink,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppPalette.muted,
                        ),
                      ),
                    ] else
                      CompletionButton(
                        key: ValueKey<String>('completion-${group.item.id}'),
                        completed: singleCompleted,
                        onPressed: () => onToggleCompletion(onlyTime!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _MotionAnimatedSize(
          milliseconds: 240,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? DoseRail(group: group, onToggleCompletion: onToggleCompletion)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class DoseRail extends StatelessWidget {
  const DoseRail({
    required this.group,
    required this.onToggleCompletion,
    super.key,
  });

  final DayTaskGroup group;
  final ValueChanged<ReminderTime> onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    final times = group.orderedTimes;
    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 7),
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 0,
            bottom: 13,
            child: Container(width: 1, color: AppPalette.mutedLight),
          ),
          _AnimatedOrderColumn(
            gap: 6,
            estimatedHeight: 58,
            entries: [
              for (final time in times)
                _AnimatedOrderEntry(
                  id: time.id!,
                  child: DoseRow(
                    key: ValueKey<String>('dose-${time.id}'),
                    time: time,
                    sequence: time.sortOrder + 1,
                    completed: group.isCompleted(time),
                    onPressed: () => onToggleCompletion(time),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class DoseRow extends StatelessWidget {
  const DoseRow({
    required this.time,
    required this.sequence,
    required this.completed,
    required this.onPressed,
    super.key,
  });

  final ReminderTime time;
  final int sequence;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 21,
          child: Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: completed
                    ? AppPalette.mutedLight
                    : AppPalette.statusSage,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: AnimatedContainer(
            duration: appMotion(context, 140),
            decoration: BoxDecoration(
              color: completed
                  ? AppPalette.childNoteDone
                  : AppPalette.childNote,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '第 $sequence 次',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: completed ? AppPalette.muted : AppPalette.ink,
                      ),
                    ),
                  ),
                  Text(
                    time.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: completed
                          ? AppPalette.mutedLight
                          : AppPalette.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  CompletionButton(completed: completed, onPressed: onPressed),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CompletionButton extends StatefulWidget {
  const CompletionButton({
    required this.completed,
    required this.onPressed,
    super.key,
  });

  final bool completed;
  final VoidCallback onPressed;

  @override
  State<CompletionButton> createState() => _CompletionButtonState();
}

class _CompletionButtonState extends State<CompletionButton>
    with SingleTickerProviderStateMixin {
  // Fill first, then draw the check while the filled circle pops and settles.
  static const _completeDuration = Duration(milliseconds: 460);
  static const _undoDuration = Duration(milliseconds: 220);

  late final AnimationController _progress;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: _completeDuration,
      reverseDuration: _undoDuration,
      value: widget.completed ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _progress.value = widget.completed ? 1 : 0;
  }

  @override
  void didUpdateWidget(CompletionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completed == widget.completed) return;
    if (_reduceMotion) {
      _progress.value = widget.completed ? 1 : 0;
    } else if (widget.completed) {
      _progress.forward();
    } else {
      _progress.reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: widget.completed,
      label: widget.completed ? '撤销完成' : '标记完成',
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: widget.completed ? '撤销完成' : '完成',
          onPressed: widget.onPressed,
          icon: CustomPaint(
            key: widget.completed ? const Key('completed-check') : null,
            size: const Size.square(25),
            painter: _CompletionPainter(_progress),
          ),
        ),
      ),
    );
  }
}

class _CompletionPainter extends CustomPainter {
  _CompletionPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static const _fillCurve = Interval(0, 0.38, curve: Curves.easeOutCubic);
  static const _checkCurve = Interval(0.34, 0.78, curve: Curves.easeInOutCubic);
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 38),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.18,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 18,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.18,
        end: 0.96,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 22,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.96,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 22,
    ),
  ]);
  static final Path _check = Path()
    ..moveTo(6.8, 12.5)
    ..lineTo(10.5, 16.2)
    ..lineTo(18.2, 8.6);
  static final PathMetric _checkMetric = _check.computeMetrics().single;

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    final fill = _fillCurve.transform(value);
    final check = _checkCurve.transform(value);
    final scale = _scale.transform(value) * size.shortestSide / 25;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-12.5, -12.5);
    const center = Offset(12.5, 12.5);

    if (fill > 0) {
      canvas.drawCircle(center, 12.5 * fill, Paint()..color = AppPalette.pine);
    }
    canvas.drawCircle(
      center,
      11.75,
      Paint()
        ..color = Color.lerp(AppPalette.muted, AppPalette.pine, fill)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    if (check > 0) {
      canvas.drawPath(
        _checkMetric.extractPath(0, _checkMetric.length * check),
        Paint()
          ..color = AppPalette.pineInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompletionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class EmptyDayState extends StatelessWidget {
  const EmptyDayState({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        border: Border.all(color: AppPalette.rule),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_note_outlined,
            color: AppPalette.muted,
            size: 30,
          ),
          const SizedBox(height: 12),
          Text('这一天没有事项', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '新建一个事项后，它会按周期出现在日历中。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建事项'),
          ),
        ],
      ),
    );
  }
}

class TaskListSkeleton extends StatelessWidget {
  const TaskListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 82,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: index.isEven ? AppPalette.parentNote : AppPalette.field,
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
        ),
      ),
    );
  }
}

class _EditableTime {
  const _EditableTime({this.id, required this.minuteOfDay});

  final int? id;
  final int minuteOfDay;

  String get label {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class ItemEditorPage extends StatefulWidget {
  const ItemEditorPage({required this.store, this.item, super.key});

  final DailyStore store;
  final ReminderItem? item;

  @override
  State<ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends State<ItemEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late String _iconKey;
  late DateTime _startDate;
  late DateTime? _endDate;
  late RepeatKind _repeatKind;
  late int _intervalDays;
  late Set<int> _weekdays;
  late List<_EditableTime> _times;
  late final TextEditingController _stockController;
  late final TextEditingController _doseController;
  late String _stockUnit;
  late DateTime? _productionDate;
  late DateTime? _expiryDate;
  late bool _snoozeEnabled;
  late int _snoozeMinutes;
  late bool _alertMonthBefore;
  late bool _alertWeekBefore;
  bool _saving = false;

  String get _frequencyLabel => switch (_repeatKind) {
    RepeatKind.daily => '每天 · ${_times.length} 次',
    RepeatKind.weekly => '选定日 · ${_times.length} 次',
    RepeatKind.interval => '每 $_intervalDays 天 · ${_times.length} 次',
  };

  int get _frequencyDays => switch (_repeatKind) {
    RepeatKind.daily => 1,
    RepeatKind.weekly => _intervalDays.clamp(2, 365),
    RepeatKind.interval => _intervalDays.clamp(2, 365),
  };

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final today = dateOnly(DateTime.now());
    _titleController = TextEditingController(text: item?.title ?? '');
    _iconKey = item?.iconKey ?? 'medication';
    _startDate = item?.startDate ?? today;
    _endDate = item?.endDate;
    _repeatKind = item?.repeatKind ?? RepeatKind.daily;
    _intervalDays = item?.intervalDays ?? 2;
    _weekdays = Set<int>.from(item?.weekdays ?? <int>{today.weekday});
    _stockController = TextEditingController(
      text: item?.stockQuantity == null
          ? ''
          : quantityLabel(item!.stockQuantity!),
    );
    _doseController = TextEditingController(
      text: quantityLabel(item?.doseQuantity ?? 1),
    );
    _stockUnit = item?.stockUnit ?? '片';
    _productionDate = item?.productionDate;
    _expiryDate = item?.expiryDate;
    _times = (item?.times ?? const <ReminderTime>[])
        .map(
          (time) => _EditableTime(id: time.id, minuteOfDay: time.minuteOfDay),
        )
        .toList();
    if (_times.isEmpty) _times = [_EditableTime(minuteOfDay: 9 * 60)];
    _snoozeEnabled = item?.snoozeMinutes != null;
    _snoozeMinutes = item?.snoozeMinutes ?? 30;
    _alertMonthBefore = item?.alertMonthBefore ?? true;
    _alertWeekBefore = item?.alertWeekBefore ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _stockController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickDate(_startDate);
    if (picked == null) return;
    setState(() {
      _startDate = dateOnly(picked);
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickDate(
      _endDate ?? _startDate.add(const Duration(days: 7)),
    );
    if (picked == null) return;
    if (dateOnly(picked).isBefore(_startDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束日期不能早于开始日期')));
      return;
    }
    setState(() => _endDate = dateOnly(picked));
  }

  Future<void> _pickProductionDate() async {
    final picked = await _pickDate(_productionDate ?? dateOnly(DateTime.now()));
    if (picked == null || !mounted) return;
    setState(() => _productionDate = dateOnly(picked));
  }

  Future<void> _pickExpiryDate() async {
    final picked = await _pickDate(
      _expiryDate ?? _productionDate ?? dateOnly(DateTime.now()),
    );
    if (picked == null || !mounted) return;
    setState(() => _expiryDate = dateOnly(picked));
  }

  Future<void> _pickTime(int index) async {
    final current = _times[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.minuteOfDay ~/ 60,
        minute: current.minuteOfDay % 60,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final minuteOfDay = picked.hour * 60 + picked.minute;
    if (_times.asMap().entries.any(
      (entry) => entry.key != index && entry.value.minuteOfDay == minuteOfDay,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这个提醒时间已经存在')));
      return;
    }
    setState(() {
      _times[index] = _EditableTime(id: current.id, minuteOfDay: minuteOfDay);
      _times.sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    });
  }

  Future<void> _pickFrequency() async {
    FocusScope.of(context).unfocus();
    final selection = await showModalBottomSheet<_FrequencySelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppPalette.canvasRaised,
      barrierColor: AppPalette.ink.withValues(alpha: 0.26),
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: AnimationStyle(
        duration: appMotion(context, 280),
        reverseDuration: appMotion(context, 220),
      ),
      builder: (context) => _FrequencyPickerSheet(
        initialDays: _frequencyDays,
        initialTimes: _times.length.clamp(1, 8),
        allowDaySelection: _repeatKind != RepeatKind.weekly,
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      if (_repeatKind != RepeatKind.weekly) {
        _intervalDays = selection.days;
        _repeatKind = selection.days == 1
            ? RepeatKind.daily
            : RepeatKind.interval;
      }
      _resizeTimes(selection.times);
    });
    HapticFeedback.lightImpact();
  }

  void _resizeTimes(int requestedCount) {
    final count = requestedCount.clamp(1, 8);
    if (count == _times.length) return;
    if (count < _times.length) {
      final current = List<_EditableTime>.from(_times);
      if (count == 1) {
        _times = [current.first];
        return;
      }
      _times = [
        for (var index = 0; index < count; index++)
          current[(index * (current.length - 1) / (count - 1)).round()],
      ];
      return;
    }

    final used = _times.map((time) => time.minuteOfDay).toSet();
    const preferredMinutes = <int>[
      9 * 60,
      20 * 60,
      13 * 60,
      17 * 60,
      8 * 60,
      11 * 60,
      15 * 60,
      22 * 60,
    ];
    for (final minute in preferredMinutes) {
      if (_times.length >= count) break;
      if (used.add(minute)) {
        _times.add(_EditableTime(minuteOfDay: minute));
      }
    }
    for (var minute = 7 * 60; _times.length < count; minute += 30) {
      if (minute > 23 * 60 + 30) minute = 0;
      if (used.add(minute)) {
        _times.add(_EditableTime(minuteOfDay: minute));
      }
    }
    _times.sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productionDate != null &&
        _expiryDate != null &&
        _expiryDate!.isBefore(_productionDate!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('有效期不能早于生产日期')));
      return;
    }
    if (_repeatKind == RepeatKind.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每周重复至少选择一天')));
      return;
    }
    setState(() => _saving = true);
    try {
      final item = ReminderItem(
        id: widget.item?.id,
        title: _titleController.text.trim(),
        iconKey: _iconKey,
        startDate: _startDate,
        endDate: _endDate,
        repeatKind: _repeatKind,
        intervalDays: _intervalDays,
        weekdays: _repeatKind == RepeatKind.weekly ? _weekdays : const <int>{},
        stockQuantity: _stockController.text.trim().isEmpty
            ? null
            : double.parse(_stockController.text.trim()),
        doseQuantity: double.parse(_doseController.text.trim()),
        stockUnit: _stockUnit,
        productionDate: _productionDate,
        expiryDate: _expiryDate,
        usedQuantityBase: widget.item?.usedQuantityBase ?? 0,
        usedQuantity: widget.item?.usedQuantity ?? 0,
        times: [
          for (var index = 0; index < _times.length; index++)
            ReminderTime(
              id: _times[index].id,
              itemId: widget.item?.id,
              minuteOfDay: _times[index].minuteOfDay,
              sortOrder: index,
            ),
        ],
        snoozeMinutes: _snoozeEnabled ? _snoozeMinutes : null,
        alertMonthBefore: _endDate != null && _alertMonthBefore,
        alertWeekBefore: _endDate != null && _alertWeekBefore,
        archived: widget.item?.archived ?? false,
        createdAt: widget.item?.createdAt,
      );
      await widget.store.saveItem(item);
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('事项没有保存，请检查后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
            children: [
              PageTopBar(
                title: widget.item == null ? '新建事项' : '编辑事项',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 22),
              const SectionLabel('名称'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('item-title-field'),
                controller: _titleController,
                textInputAction: TextInputAction.done,
                maxLength: 30,
                decoration: const InputDecoration(
                  hintText: '例如：维生素 D',
                  counterText: '',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请填写事项名称' : null,
              ),
              const SizedBox(height: 18),
              const SectionLabel('图标'),
              const SizedBox(height: 8),
              FormSurface(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      const {
                        'medication': Icons.medication_outlined,
                        'vitamin': Icons.eco_outlined,
                        'exercise': Icons.fitness_center_rounded,
                        'eye': Icons.visibility_outlined,
                        'water': Icons.water_drop_outlined,
                      }.entries.map((entry) {
                        final selected = _iconKey == entry.key;
                        return ChoiceChip(
                          key: ValueKey<String>('icon-${entry.key}'),
                          selected: selected,
                          showCheckmark: false,
                          avatar: Icon(
                            entry.value,
                            size: 20,
                            color: selected
                                ? AppPalette.pineInk
                                : AppPalette.ink,
                          ),
                          label: Text(switch (entry.key) {
                            'vitamin' => '营养',
                            'exercise' => '运动',
                            'eye' => '护理',
                            'water' => '饮水',
                            _ => '用药',
                          }),
                          selectedColor: AppPalette.pine,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppPalette.pineInk
                                : AppPalette.ink,
                          ),
                          onSelected: (_) {
                            setState(() => _iconKey = entry.key);
                            HapticFeedback.selectionClick();
                          },
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('日期'),
              const SizedBox(height: 8),
              FormSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    FormActionRow(
                      icon: Icons.calendar_today_outlined,
                      label: '开始',
                      value: shortDate(_startDate),
                      onTap: _pickStartDate,
                    ),
                    const Divider(indent: 52),
                    FormActionRow(
                      icon: Icons.event_available_outlined,
                      label: '结束',
                      value: _endDate == null ? '长期' : shortDate(_endDate!),
                      onTap: _pickEndDate,
                      trailing: _endDate == null
                          ? null
                          : IconButton(
                              tooltip: '设为长期',
                              onPressed: () => setState(() => _endDate = null),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('药品与库存'),
              const SizedBox(height: 6),
              Text(
                '录入后按实际完成次数扣减，留空则不统计库存',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('stock-quantity-field'),
                      controller: _stockController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '录入数量',
                        hintText: '选填',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final amount = double.tryParse(value.trim());
                        return amount == null ||
                                !amount.isFinite ||
                                amount < 0 ||
                                !RegExp(
                                  r'^\d+(\.\d{1,2})?$',
                                ).hasMatch(value.trim())
                            ? '请输入不小于 0 的数字'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: const Key('dose-quantity-field'),
                      controller: _doseController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '每次用量'),
                      validator: (value) {
                        final amount = double.tryParse(value?.trim() ?? '');
                        return amount == null ||
                                !amount.isFinite ||
                                amount <= 0 ||
                                !RegExp(
                                  r'^\d+(\.\d{1,2})?$',
                                ).hasMatch(value!.trim())
                            ? '请输入大于 0 的数字'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const Key('stock-unit-field'),
                initialValue: _stockUnit,
                decoration: const InputDecoration(labelText: '单位'),
                items: const ['片', '粒', '支', '袋', '毫升', '滴', '贴', '盒']
                    .map(
                      (unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _stockUnit = value);
                },
              ),
              if (widget.item?.stockQuantity != null) ...[
                const SizedBox(height: 8),
                Text(
                  '已记录使用 ${quantityLabel(widget.item!.usedQuantity)} $_stockUnit；修改录入数量后，历史消耗仍保留',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              FormSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    FormActionRow(
                      icon: Icons.factory_outlined,
                      label: '生产日期',
                      value: _productionDate == null
                          ? '未填写'
                          : yearDate(_productionDate!),
                      onTap: _pickProductionDate,
                      trailing: _productionDate == null
                          ? null
                          : IconButton(
                              tooltip: '清除生产日期',
                              onPressed: () =>
                                  setState(() => _productionDate = null),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                    ),
                    const Divider(indent: 52),
                    FormActionRow(
                      icon: Icons.event_busy_outlined,
                      label: '有效期至',
                      value: _expiryDate == null
                          ? '未填写'
                          : yearDate(_expiryDate!),
                      onTap: _pickExpiryDate,
                      trailing: _expiryDate == null
                          ? null
                          : IconButton(
                              tooltip: '清除有效期',
                              onPressed: () =>
                                  setState(() => _expiryDate = null),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('重复'),
              const SizedBox(height: 8),
              FormSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<RepeatKind>(
                      segments: const [
                        ButtonSegment(
                          value: RepeatKind.daily,
                          label: Text('每天'),
                        ),
                        ButtonSegment(
                          value: RepeatKind.weekly,
                          label: Text('每周'),
                        ),
                        ButtonSegment(
                          value: RepeatKind.interval,
                          label: Text('隔几天'),
                        ),
                      ],
                      selected: {_repeatKind},
                      onSelectionChanged: (value) {
                        final repeatKind = value.single;
                        setState(() {
                          _repeatKind = repeatKind;
                          if (repeatKind == RepeatKind.interval &&
                              _intervalDays < 2) {
                            _intervalDays = 2;
                          }
                        });
                        HapticFeedback.selectionClick();
                      },
                    ),
                    _MotionAnimatedSize(
                      milliseconds: 220,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _repeatKind == RepeatKind.weekly
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: List.generate(7, (index) {
                                  final day = index + 1;
                                  const labels = [
                                    '一',
                                    '二',
                                    '三',
                                    '四',
                                    '五',
                                    '六',
                                    '日',
                                  ];
                                  return FilterChip(
                                    label: Text(labels[index]),
                                    selected: _weekdays.contains(day),
                                    showCheckmark: false,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _weekdays.add(day);
                                        } else {
                                          _weekdays.remove(day);
                                        }
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                  );
                                }),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('提醒时间'),
              const SizedBox(height: 8),
              FormSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    FormActionRow(
                      key: const Key('frequency-picker-row'),
                      icon: Icons.repeat_rounded,
                      label: '服用频率',
                      value: _frequencyLabel,
                      onTap: _pickFrequency,
                    ),
                    const Divider(indent: 52),
                    _MotionAnimatedSize(
                      milliseconds: 240,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < _times.length;
                            index++
                          ) ...[
                            FormActionRow(
                              key: ValueKey<String>('editor-time-$index'),
                              icon: Icons.schedule_rounded,
                              label: _times.length == 1
                                  ? '时间'
                                  : '第 ${index + 1} 次',
                              value: _times[index].label,
                              onTap: () => _pickTime(index),
                            ),
                            if (index != _times.length - 1)
                              const Divider(indent: 52),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('重复提醒'),
              const SizedBox(height: 8),
              FormSurface(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('间隔一段时间再提醒'),
                      subtitle: const Text('提醒不会替你完成事项'),
                      value: _snoozeEnabled,
                      activeTrackColor: AppPalette.pine,
                      onChanged: (value) =>
                          setState(() => _snoozeEnabled = value),
                    ),
                    if (_snoozeEnabled)
                      Wrap(
                        spacing: 8,
                        children: [10, 30, 60]
                            .map(
                              (minutes) => ChoiceChip(
                                selected: _snoozeMinutes == minutes,
                                showCheckmark: false,
                                label: Text('$minutes 分钟'),
                                onSelected: (_) =>
                                    setState(() => _snoozeMinutes = minutes),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              if (_endDate != null) ...[
                const SizedBox(height: 18),
                const SectionLabel('周期结束前提醒'),
                const SizedBox(height: 8),
                FormSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('提前一个月'),
                        value: _alertMonthBefore,
                        activeTrackColor: AppPalette.pine,
                        onChanged: (value) =>
                            setState(() => _alertMonthBefore = value),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      SwitchListTile.adaptive(
                        title: const Text('提前一周'),
                        value: _alertWeekBefore,
                        activeTrackColor: AppPalette.pine,
                        onChanged: (value) =>
                            setState(() => _alertWeekBefore = value),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const Key('save-item-button'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.pine,
                    foregroundColor: AppPalette.pineInk,
                    elevation: 3,
                    shadowColor: AppPalette.pine.withValues(alpha: 0.28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.pineInk,
                          ),
                        )
                      : const Text('保存事项'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}

class FormSurface extends StatelessWidget {
  const FormSurface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.field,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppPalette.rule),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class FormActionRow extends StatelessWidget {
  const FormActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              Icon(icon, color: AppPalette.muted, size: 22),
              const SizedBox(width: 14),
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              trailing ??
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.chevron_right_rounded, size: 21),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequencySelection {
  const _FrequencySelection({required this.days, required this.times});

  final int days;
  final int times;
}

class _FrequencyPickerSheet extends StatefulWidget {
  const _FrequencyPickerSheet({
    required this.initialDays,
    required this.initialTimes,
    required this.allowDaySelection,
  });

  final int initialDays;
  final int initialTimes;
  final bool allowDaySelection;

  @override
  State<_FrequencyPickerSheet> createState() => _FrequencyPickerSheetState();
}

class _FrequencyPickerSheetState extends State<_FrequencyPickerSheet> {
  late int _days;
  late int _times;
  late final FixedExtentScrollController _daysController;
  late final FixedExtentScrollController _timesController;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays.clamp(1, 365);
    _times = widget.initialTimes.clamp(1, 8);
    _daysController = FixedExtentScrollController(initialItem: _days - 1);
    _timesController = FixedExtentScrollController(initialItem: _times - 1);
  }

  @override
  void dispose() {
    _daysController.dispose();
    _timesController.dispose();
    super.dispose();
  }

  String get _summary {
    if (!widget.allowDaySelection) return '每个选定日 · $_times 次';
    if (_days == 1) return '每天 · $_times 次';
    return '每 $_days 天 · $_times 次';
  }

  Widget _numberWheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int selectedValue,
    required int childCount,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      height: 188,
      child: CupertinoPicker.builder(
        key: key,
        scrollController: controller,
        itemExtent: 46,
        diameterRatio: 1.35,
        squeeze: 1.08,
        useMagnifier: true,
        magnification: 1.06,
        selectionOverlay: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppPalette.parentNote.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(color: AppPalette.pine.withValues(alpha: 0.18)),
          ),
        ),
        childCount: childCount,
        onSelectedItemChanged: (index) => onChanged(index + 1),
        itemBuilder: (context, index) {
          final value = index + 1;
          final selected = value == selectedValue;
          return Center(
            child: AnimatedDefaultTextStyle(
              duration: appMotion(context, 140),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: selected ? AppPalette.pine : AppPalette.muted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              child: Text('$value $suffix'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final wheels = <Widget>[
      if (widget.allowDaySelection)
        Expanded(
          child: Semantics(
            label: '间隔天数',
            value: '$_days 天',
            child: Column(
              children: [
                Text('间隔天数', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                _numberWheel(
                  key: const Key('frequency-days-wheel'),
                  controller: _daysController,
                  selectedValue: _days,
                  childCount: 365,
                  suffix: '天',
                  onChanged: (value) => setState(() => _days = value),
                ),
              ],
            ),
          ),
        ),
      if (widget.allowDaySelection) const SizedBox(width: 12),
      Expanded(
        child: Semantics(
          label: '当天次数',
          value: '$_times 次',
          child: Column(
            children: [
              Text(
                widget.allowDaySelection ? '当天次数' : '每日次数',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              _numberWheel(
                key: const Key('frequency-times-wheel'),
                controller: _timesController,
                selectedValue: _times,
                childCount: 8,
                suffix: '次',
                onChanged: (value) => setState(() => _times = value),
              ),
            ],
          ),
        ),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '服用频率',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.allowDaySelection
                          ? '滚动设置间隔天数和当天次数'
                          : '滚动设置每个选定日的次数',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('frequency-picker-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                key: const Key('frequency-picker-confirm'),
                onPressed: () => Navigator.of(
                  context,
                ).pop(_FrequencySelection(days: _days, times: _times)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(76, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('完成'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: appMotion(context, 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              _summary,
              key: ValueKey<String>(_summary),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppPalette.pine),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: wheels),
        ],
      ),
    );
  }
}

enum _ItemFilter { active, ended, all }

class ItemsPage extends StatefulWidget {
  const ItemsPage({
    required this.store,
    required this.scheduler,
    required this.revision,
    required this.onAdd,
    required this.onEdit,
    required this.onOpenSettings,
    required this.onDataChanged,
    super.key,
  });

  final DailyStore store;
  final ReminderScheduler scheduler;
  final int revision;
  final VoidCallback onAdd;
  final ValueChanged<ReminderItem> onEdit;
  final VoidCallback onOpenSettings;
  final VoidCallback onDataChanged;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  List<ReminderItem> _items = const [];
  _ItemFilter _filter = _ItemFilter.active;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ItemsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    final items = await widget.store.loadItems(includeArchived: true);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<ReminderItem> get _filteredItems => switch (_filter) {
    _ItemFilter.active =>
      _items.where((item) => !item.hasEnded && !item.archived).toList(),
    _ItemFilter.ended =>
      _items.where((item) => item.hasEnded || item.archived).toList(),
    _ItemFilter.all => _items,
  };

  Future<void> _delete(ReminderItem item) async {
    final itemId = item.id;
    if (itemId == null) return;
    final previous = List<ReminderItem>.from(_items);
    setState(
      () => _items = _items.where((entry) => entry.id != itemId).toList(),
    );
    try {
      final deleted = await widget.store.deleteItem(itemId);
      if (deleted == null) throw StateError('Reminder no longer exists.');
      widget.onDataChanged();
      await widget.scheduler.sync(await widget.store.loadItems());
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: Text('已删除“${item.title}”'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              try {
                await widget.store.restoreDeletedItem(deleted);
                await widget.scheduler.sync(await widget.store.loadItems());
                widget.onDataChanged();
                await _load();
              } on Object {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('未能恢复事项，请再试一次')));
              }
            },
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _items = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未能删除事项，请再试一次')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredItems;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppPalette.pine,
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey<String>('items-page'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '事项',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                SoftIconButton(
                  icon: Icons.add_rounded,
                  tooltip: '新建事项',
                  onPressed: widget.onAdd,
                ),
                const SizedBox(width: 8),
                SoftIconButton(
                  key: const Key('items-settings-button'),
                  icon: Icons.settings_rounded,
                  tooltip: '设置',
                  onPressed: widget.onOpenSettings,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ItemFilterBar(
              selected: _filter,
              counts: {
                _ItemFilter.active: _items
                    .where((item) => !item.hasEnded && !item.archived)
                    .length,
                _ItemFilter.ended: _items
                    .where((item) => item.hasEnded || item.archived)
                    .length,
                _ItemFilter.all: _items.length,
              },
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const TaskListSkeleton()
            else if (visible.isEmpty)
              _ItemsEmptyState(filter: _filter, onAdd: widget.onAdd)
            else
              ...visible.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ManagementItemCard(
                    item: item,
                    onEdit: () => widget.onEdit(item),
                    onDelete: () => _delete(item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemFilterBar extends StatelessWidget {
  const _ItemFilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _ItemFilter selected;
  final Map<_ItemFilter, int> counts;
  final ValueChanged<_ItemFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _ItemFilter.active: '进行中',
      _ItemFilter.ended: '已结束',
      _ItemFilter.all: '全部',
    };
    return Row(
      children: _ItemFilter.values.map((filter) {
        final active = selected == filter;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              onPressed: () => onSelected(filter),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: active ? AppPalette.ink : AppPalette.muted,
                backgroundColor: active
                    ? AppPalette.parentNote
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
              ),
              child: Text('${labels[filter]}  ${counts[filter] ?? 0}'),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ManagementItemCard extends StatelessWidget {
  const _ManagementItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ReminderItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ended = item.hasEnded || item.archived;
    final inventoryLabel = inventoryStatusLabel(item);
    final expiryLabel = expiryStatusLabel(item, DateTime.now());
    return Material(
      color: ended ? AppPalette.completedNote : AppPalette.canvasRaised,
      borderRadius: BorderRadius.circular(AppRadii.large),
      elevation: ended ? 0 : 1,
      shadowColor: AppPalette.pine.withValues(alpha: 0.13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                iconForKey(item.iconKey),
                color: ended ? AppPalette.muted : AppPalette.pine,
                size: 26,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${item.times.length} 次/天',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.endDate == null
                          ? '${item.scheduleLabel} · 长期'
                          : '${item.scheduleLabel} · ${shortDate(item.startDate)}–${shortDate(item.endDate!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (inventoryLabel != null || expiryLabel != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        [
                          inventoryLabel,
                          expiryLabel,
                        ].whereType<String>().join(' · '),
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              (item.remainingQuantity ?? 1) <= 0 ||
                                  (item.expiryDate != null &&
                                      dateOnly(
                                        item.expiryDate!,
                                      ).isBefore(dateOnly(DateTime.now())))
                              ? AppPalette.missed
                              : AppPalette.pine,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.times
                          .map(
                            (time) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.field,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                              child: Text(
                                time.label,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemsEmptyState extends StatelessWidget {
  const _ItemsEmptyState({required this.filter, required this.onAdd});

  final _ItemFilter filter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final canAdd = filter != _ItemFilter.ended;
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          const Icon(
            Icons.format_list_bulleted_rounded,
            size: 32,
            color: AppPalette.muted,
          ),
          const SizedBox(height: 14),
          Text(
            filter == _ItemFilter.ended ? '没有已结束事项' : '还没有事项',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            canAdd ? '建立第一条记录，它会出现在对应日期。' : '结束周期的事项会保留在这里。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (canAdd) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建事项'),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.store,
    required this.scheduler,
    required this.revision,
    super.key,
  });

  final DailyStore store;
  final ReminderScheduler scheduler;
  final int revision;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ReminderHealth? _reminderHealth;
  int _itemCount = 0;
  int _completionCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      widget.scheduler.health(),
      widget.store.loadItems(includeArchived: true),
      widget.store.completionCount(),
    ]);
    if (!mounted) return;
    setState(() {
      _reminderHealth = results[0] as ReminderHealth;
      _itemCount = (results[1] as List<ReminderItem>).length;
      _completionCount = results[2] as int;
    });
  }

  Future<void> _requestPermission() async {
    final allowed = await widget.scheduler.requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(allowed ? '通知已开启' : '通知未开启，可在系统设置中允许')),
    );
    await _load();
  }

  Future<void> _requestExactAlarmPermission() async {
    final allowed = await widget.scheduler.requestExactAlarmPermission();
    if (allowed) {
      await widget.scheduler.sync(await widget.store.loadItems());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(allowed ? '准时提醒已开启' : '未开启准时提醒，系统可能延迟事项通知'),
        duration: const Duration(seconds: 2),
      ),
    );
    await _load();
  }

  Future<void> _testNotification() async {
    var allowed = _reminderHealth?.notificationsEnabled ?? false;
    if (!allowed) allowed = await widget.scheduler.requestPermission();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要通知权限才能发送测试提醒')));
      return;
    }
    await widget.scheduler.showTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('测试提醒已发送，请展开通知查看两个操作按钮')));
    await _load();
  }

  String _syncLabel(DateTime? value) {
    if (value == null) return '本次启动尚未调度';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '最近检查 $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            PageTopBar(title: '设置', onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: SectionLabel('提醒检查')),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重新检查'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FormSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    minTileHeight: 58,
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('系统通知'),
                    subtitle: Text(
                      _reminderHealth == null
                          ? '正在读取状态'
                          : _reminderHealth!.notificationsEnabled
                          ? '已允许'
                          : '未允许',
                    ),
                    trailing: TextButton(
                      onPressed: _reminderHealth?.notificationsEnabled == true
                          ? widget.scheduler.openNotificationSettings
                          : _requestPermission,
                      child: Text(
                        _reminderHealth?.notificationsEnabled == true
                            ? '设置'
                            : '开启',
                      ),
                    ),
                    onTap: _reminderHealth?.notificationsEnabled == true
                        ? widget.scheduler.openNotificationSettings
                        : _requestPermission,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    minTileHeight: 58,
                    leading: Icon(
                      _reminderHealth?.exactAlarmAllowed == true
                          ? Icons.alarm_on_rounded
                          : Icons.alarm_off_rounded,
                    ),
                    title: const Text('准时提醒'),
                    subtitle: Text(
                      _reminderHealth == null
                          ? '正在读取状态'
                          : _reminderHealth!.exactAlarmAllowed
                          ? '已允许，可按设定时间触发'
                          : '未允许，系统可能延迟事项通知',
                    ),
                    trailing: _reminderHealth?.exactAlarmAllowed == true
                        ? const Icon(Icons.check_rounded)
                        : TextButton(
                            onPressed: _requestExactAlarmPermission,
                            child: const Text('开启'),
                          ),
                    onTap: _reminderHealth?.exactAlarmAllowed == true
                        ? null
                        : _requestExactAlarmPermission,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    minTileHeight: 58,
                    leading: Icon(
                      _reminderHealth?.reminderChannelCanPopUp == true
                          ? Icons.mark_chat_unread_outlined
                          : Icons.comments_disabled_outlined,
                    ),
                    title: const Text('提醒弹窗渠道'),
                    subtitle: Text(
                      _reminderHealth == null
                          ? '正在读取状态'
                          : !_reminderHealth!.reminderChannelEnabled
                          ? '渠道已关闭'
                          : _reminderHealth!.reminderChannelCanPopUp
                          ? '高优先级，可显示顶部提醒'
                          : '当前可能只在通知栏静默显示',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.scheduler.openNotificationSettings,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    minTileHeight: 58,
                    leading: Icon(
                      _reminderHealth?.batteryOptimizationIgnored == true
                          ? Icons.battery_charging_full_rounded
                          : Icons.battery_alert_outlined,
                    ),
                    title: const Text('后台运行'),
                    subtitle: Text(
                      _reminderHealth == null
                          ? '正在读取状态'
                          : _reminderHealth!.batteryOptimizationIgnored
                          ? '未受电池优化限制'
                          : '可能被电池优化延迟',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.scheduler.openBatterySettings,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    minTileHeight: 58,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('已调度提醒'),
                    subtitle: Text(_syncLabel(_reminderHealth?.lastSyncedAt)),
                    trailing: Text(
                      _reminderHealth == null
                          ? '—'
                          : '${_reminderHealth!.pendingCount} 条',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    minTileHeight: 58,
                    leading: const Icon(Icons.notification_add_outlined),
                    title: const Text('测试提醒'),
                    subtitle: const Text('立即发送，包含“完成”和“稍后提醒”'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _testNotification,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('本地数据'),
            const SizedBox(height: 8),
            FormSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DataFigure(value: '$_itemCount', label: '事项'),
                      const SizedBox(width: 28),
                      _DataFigure(value: '$_completionCount', label: '完成记录'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '事项与完成记录只保存在这台设备的 SQLite 数据库中。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataFigure extends StatelessWidget {
  const _DataFigure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class PageTopBar extends StatelessWidget {
  const PageTopBar({required this.title, required this.onBack, super.key});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SoftIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: '返回',
              onPressed: onBack,
              transparent: true,
            ),
          ),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.transparent = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: transparent ? Colors.transparent : AppPalette.field,
      shape: const CircleBorder(),
      elevation: transparent ? 0 : 1,
      shadowColor: AppPalette.pine.withValues(alpha: 0.14),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppPalette.ink, size: 24),
      ),
    );
  }
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: AppPalette.canvas,
          border: Border(top: BorderSide(color: AppPalette.rule)),
        ),
        child: Row(
          children: [
            _BottomNavigationItem(
              label: '日历',
              icon: Icons.calendar_month_outlined,
              selectedIcon: Icons.calendar_month_rounded,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _BottomNavigationItem(
              label: '事项',
              icon: Icons.format_list_bulleted_rounded,
              selectedIcon: Icons.format_list_bulleted_rounded,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.pine : AppPalette.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: appMotion(context, 180),
                curve: Curves.easeOutCubic,
                width: 54,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? AppPalette.parentNote : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
