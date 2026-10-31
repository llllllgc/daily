// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · route: custom (tuned) · vibe: mineral, quiet, botanical, precise
// Hallmark · structure: calendar-first index + in-place indented dose rail
// Hallmark · axes: light / editorial-serif / chromatic-sage · studied: yes
// Hallmark · audit: contrast pass · mobile pass · tokens pass · states pass

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'services/notification_service.dart';
import 'theme.dart';
import 'item_icons.dart';
import 'widgets/item_icon.dart';
import 'widgets/motion.dart';

export 'widgets/motion.dart' show appMotion;
export 'theme.dart' show AppPalette, DailyColors, DailyColorContext;

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

String courseDetailsLabel(ReminderItem item) {
  final period = item.endDate == null ? '长期' : '截止${yearDate(item.endDate!)}';
  if (!ItemIcons.showsDose(item.iconKey) && item.stockQuantity == null) {
    return '$period · ${item.scheduleLabel}';
  }
  return '$period · 每次${quantityLabel(item.doseQuantity)}${item.stockUnit}';
}

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

  static ThemeData get light => forColor(DailyThemeColor.sage);

  static ThemeData forColor(DailyThemeColor color) {
    final colors = DailyColors.forTheme(color);
    final scheme = ColorScheme.light(
      primary: colors.pine,
      onPrimary: colors.pineInk,
      secondary: colors.parentNote,
      onSecondary: colors.ink,
      surface: colors.canvas,
      onSurface: colors.ink,
      error: colors.missed,
      onError: colors.pineInk,
      outline: colors.rule,
    );
    return ThemeData(
      useMaterial3: true,
      extensions: [colors],
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      fontFamily: 'Noto Sans SC',
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: colors.ink,
          fontSize: 43,
          height: 1.04,
          fontWeight: FontWeight.w500,
          letterSpacing: -1.5,
        ),
        headlineLarge: TextStyle(
          color: colors.ink,
          fontSize: 31,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: colors.ink,
          fontSize: 23,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        titleLarge: TextStyle(
          color: colors.ink,
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: colors.ink,
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: colors.ink,
          fontSize: 16,
          height: 1.42,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: colors.inkSoft,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: colors.muted,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: colors.ink,
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.rule,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.field,
        hintStyle: TextStyle(color: colors.mutedLight),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: colors.rule),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.rule),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.pine),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.missed),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.missed),
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: TextStyle(color: colors.pineInk),
        actionTextColor: colors.completionFill,
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          elevation: 2,
          shadowColor: colors.pine.withValues(alpha: 0.22),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.pine,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class DailyApp extends StatefulWidget {
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
  State<DailyApp> createState() => _DailyAppState();
}

class _DailyAppState extends State<DailyApp> {
  late DailyThemeController _theme;

  @override
  void initState() {
    super.initState();
    _theme = DailyThemeController(widget.store)..load();
  }

  @override
  void didUpdateWidget(DailyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store == widget.store) return;
    _theme.dispose();
    _theme = DailyThemeController(widget.store)..load();
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DailyThemeScope(
      controller: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => MaterialApp(
          title: 'Daily',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forColor(_theme.color),
          themeAnimationDuration:
              MediaQuery.maybeDisableAnimationsOf(context) == true
              ? Duration.zero
              : const Duration(milliseconds: 220),
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: context.palette.canvas,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: child!,
          ),
          home: DailyShell(
            store: widget.store,
            scheduler: widget.scheduler,
            refreshSignal: widget.refreshSignal,
          ),
        ),
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
  bool _editingTime = false;

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

  Future<void> _editReminderTime(ReminderItem item, ReminderTime time) async {
    if (_editingTime) return;
    _editingTime = true;
    var saved = false;
    try {
      final picked = await showTimePicker(
        context: context,
        helpText: '修改提醒时间',
        initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (picked == null || !mounted) return;
      final minute = picked.hour * 60 + picked.minute;
      if (minute == time.minuteOfDay) return;
      final items = await widget.store.loadItems(includeArchived: true);
      final matches = items.where((entry) => entry.id == item.id);
      if (matches.isEmpty) return;
      final latest = matches.single;
      if (!latest.times.any((entry) => entry.id == time.id)) return;
      if (latest.times.any(
        (entry) => entry.id != time.id && entry.minuteOfDay == minute,
      )) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('这个提醒时间已经存在')));
        }
        return;
      }
      final times =
          latest.times
              .map(
                (entry) => entry.id == time.id
                    ? entry.copyWith(minuteOfDay: minute)
                    : entry,
              )
              .toList()
            ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
      await widget.store.saveItem(
        latest.copyWith(
          times: [
            for (var index = 0; index < times.length; index++)
              times[index].copyWith(sortOrder: index),
          ],
        ),
      );
      saved = true;
      _refresh();
      await _syncNotifications();
      if (mounted) {
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提醒时间已更新')));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saved ? '时间已保存，提醒同步失败，请在设置中重试' : '未能修改提醒时间，请再试一次'),
          ),
        );
      }
    } finally {
      _editingTime = false;
    }
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
        onEditTime: _editReminderTime,
      ),
      ItemsPage(
        store: widget.store,
        scheduler: widget.scheduler,
        revision: _revision,
        onAdd: _openEditor,
        onEdit: _openEditor,
        onOpenSettings: _openSettings,
        onDataChanged: _refresh,
        onEditTime: _editReminderTime,
      ),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var index = 0; index < pages.length; index++)
            MotionPageEntrance(
              active: index == _selectedIndex,
              child: pages[index],
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          if (_selectedIndex == index) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

String shortDate(DateTime date) => '${date.month} 月 ${date.day} 日';
String yearDate(DateTime date) => '${date.year}年${date.month}月${date.day}日';

String fullDate(DateTime date) {
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '${date.month} 月 ${date.day} 日 · ${weekdays[date.weekday - 1]}';
}

DateTime _weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday % 7);

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    required this.store,
    required this.revision,
    required this.onAdd,
    required this.onOpenSettings,
    required this.onDataChanged,
    required this.onEditTime,
    super.key,
  });

  final DailyStore store;
  final int revision;
  final VoidCallback onAdd;
  final VoidCallback onOpenSettings;
  final VoidCallback onDataChanged;
  final void Function(ReminderItem, ReminderTime) onEditTime;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  List<ReminderItem> _items = const [];
  Map<String, DateTime> _completionTimes = const {};
  final Set<int> _expandedItemIds = <int>{};
  final Set<String> _completionWrites = <String>{};
  final Map<String, DateTime> _completionBlockedUntil = <String, DateTime>{};
  bool _loading = true;
  int _loadVersion = 0;
  bool _monthExpanded = false;

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
    return _weekStart(first);
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    final start = _gridStart;
    final results = await Future.wait<Object>([
      widget.store.loadItems(),
      widget.store.loadCompletionTimes(
        start,
        DateTime(start.year, start.month, start.day + 41),
      ),
    ]);
    if (!mounted || version != _loadVersion) return;
    setState(() {
      _items = results[0] as List<ReminderItem>;
      final completions = Map<String, DateTime>.from(
        results[1] as Map<String, DateTime>,
      );
      for (final key in _completionWrites) {
        final timestamp = _completionTimes[key];
        if (timestamp == null) {
          completions.remove(key);
        } else {
          completions[key] = timestamp;
        }
      }
      _completionTimes = completions;
      _expandedItemIds.removeWhere(
        (id) => !_items.any((item) => item.id == id),
      );
      _loading = false;
    });
  }

  List<DayTaskGroup> get _groups {
    final completionKeys = _completionTimes.keys.toSet();
    final groups = _items
        .where((item) => item.isScheduledOn(_selectedDate))
        .map(
          (item) => DayTaskGroup(
            item: item,
            date: _selectedDate,
            completedKeys: completionKeys,
            completionTimes: _completionTimes,
          ),
        )
        .toList(growable: false);
    final originalOrder = {
      for (var index = 0; index < groups.length; index++)
        groups[index].item.id: index,
    };
    final completedGroups = groups.where((group) => group.allCompleted).toList()
      ..sort((a, b) {
        final aCompletedAt = a.lastCompletedAt;
        final bCompletedAt = b.lastCompletedAt;
        if (aCompletedAt != null && bCompletedAt != null) {
          final completionOrder = bCompletedAt.compareTo(aCompletedAt);
          if (completionOrder != 0) return completionOrder;
        }
        return originalOrder[a.item.id]!.compareTo(originalOrder[b.item.id]!);
      });
    return <DayTaskGroup>[
      ...groups.where((group) => !group.allCompleted),
      ...completedGroups,
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
    final occurrenceDate = dateOnly(group.date);
    final key = completionKey(itemId, timeId, occurrenceDate);
    final now = DateTime.now();
    if (_completionWrites.contains(key)) return;
    final blockedUntil = _completionBlockedUntil[key];
    if (!bypassDebounce && blockedUntil != null && blockedUntil.isAfter(now)) {
      return;
    }
    final previousCompletedAt = _completionTimes[key];
    final nextValue = completed ?? previousCompletedAt == null;
    // Undo may refer to a date outside the currently loaded calendar range.
    // Its absence from the visible cache does not mean it is absent on disk.
    _loadVersion++;
    _completionWrites.add(key);
    _completionBlockedUntil[key] = now.add(const Duration(milliseconds: 550));
    setState(() {
      final nextTimes = Map<String, DateTime>.from(_completionTimes);
      if (nextValue) {
        nextTimes[key] = now;
      } else {
        nextTimes.remove(key);
      }
      _completionTimes = nextTimes;
    });
    try {
      await widget.store.setCompletion(
        itemId: itemId,
        reminderTimeId: timeId,
        date: occurrenceDate,
        completed: nextValue,
        completedAt: nextValue ? now : null,
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
        final rollback = Map<String, DateTime>.from(_completionTimes);
        if (previousCompletedAt == null) {
          rollback.remove(key);
        } else {
          rollback[key] = previousCompletedAt;
        }
        _completionTimes = rollback;
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
            _completionTimes.containsKey(completionKey(itemId, timeId, date))) {
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
      DayRecordStatus.pending => context.palette.statusSage,
      DayRecordStatus.partial => context.palette.warning,
      DayRecordStatus.complete => context.palette.pine,
      DayRecordStatus.missed => context.palette.missed,
    };
  }

  void _selectDate(DateTime date) {
    final selected = dateOnly(date);
    final month = DateTime(selected.year, selected.month);
    final monthChanged = month != _visibleMonth;
    setState(() {
      _selectedDate = selected;
      _visibleMonth = month;
    });
    if (monthChanged) _load();
  }

  void _changePeriod(int delta) {
    if (_monthExpanded) {
      final month = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectDate(
        DateTime(
          month.year,
          month.month,
          math.min(
            _selectedDate.day,
            DateUtils.getDaysInMonth(month.year, month.month),
          ),
        ),
      );
    } else {
      _selectDate(
        DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day + 7 * delta,
        ),
      );
    }
  }

  void _toggleCalendar() {
    setState(() {
      _monthExpanded = !_monthExpanded;
    });
  }

  Widget _adjacentCalendar(int delta) {
    final month = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final date = _monthExpanded
        ? DateTime(
            month.year,
            month.month,
            math.min(
              _selectedDate.day,
              DateUtils.getDaysInMonth(month.year, month.month),
            ),
          )
        : DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day + delta * 7,
          );
    return CalendarDates(
      expanded: _monthExpanded,
      visibleMonth: DateTime(date.year, date.month),
      selectedDate: date,
      statusFor: _statusFor,
      onSelected: (_) {},
    );
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
        color: context.palette.pine,
        onRefresh: _load,
        child: ListView(
          key: const PageStorageKey<String>('calendar-page'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            CalendarHeader(
              visibleMonth: _visibleMonth,
              monthExpanded: _monthExpanded,
              showToday: dayKey(_selectedDate) != dayKey(DateTime.now()),
              onToggleCalendar: _toggleCalendar,
              onToday: () => _selectDate(DateTime.now()),
              onPrevious: () => _changePeriod(-1),
              onNext: () => _changePeriod(1),
              onAdd: widget.onAdd,
              onOpenSettings: widget.onOpenSettings,
            ),
            const SizedBox(height: 18),
            _MotionAnimatedSize(
              milliseconds: 220,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: SwipePeriod(
                key: const Key('calendar-swipe-area'),
                onChanged: _changePeriod,
                adjacentBuilder: _adjacentCalendar,
                child: CalendarDates(
                  expanded: _monthExpanded,
                  visibleMonth: _visibleMonth,
                  selectedDate: _selectedDate,
                  statusFor: _statusFor,
                  onSelected: _selectDate,
                ),
              ),
            ),
            const SizedBox(height: 18),
            DailySummary(
              date: _selectedDate,
              completed: completed,
              total: total,
            ),
            const SizedBox(height: 12),
            MotionSwitcher(
              animateSize: true,
              child: Column(
                key: ValueKey<String>('day-${dayKey(_selectedDate)}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const TaskListSkeleton()
                  else if (groups.isEmpty)
                    EmptyDayState(onAdd: widget.onAdd)
                  else
                    _AnimatedOrderColumn(
                      key: ValueKey<String>(
                        'day-order-${dayKey(_selectedDate)}',
                      ),
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
                              onEditTime: (time) =>
                                  widget.onEditTime(group.item, time),
                            ),
                          ),
                      ],
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
  late List<Object> _order = widget.entries.map((entry) => entry.id).toList();
  Timer? _pendingMove;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pendingMove?.cancel();
      _order = widget.entries.map((entry) => entry.id).toList();
    }
  }

  @override
  void didUpdateWidget(_AnimatedOrderColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.entries.map((entry) => entry.id).toList();
    if (listEquals(next, oldWidget.entries.map((entry) => entry.id).toList())) {
      return;
    }
    _pendingMove?.cancel();
    if (MediaQuery.disableAnimationsOf(context) ||
        !setEquals(_order.toSet(), next.toSet())) {
      _order = next;
    } else {
      _pendingMove = Timer(appMotion(context, 160), () {
        if (mounted) setState(() => _order = next);
      });
    }
  }

  @override
  void dispose() {
    _pendingMove?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    final duration = appMotion(context, 320);
    final byId = {for (final entry in widget.entries) entry.id: entry};
    final entries = [
      for (final id in _order)
        if (byId[id] != null) byId[id]!,
    ];
    final positions = <Object, double>{};
    var totalHeight = 0.0;
    for (final entry in entries) {
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
            for (final entry in entries)
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
    required this.monthExpanded,
    required this.showToday,
    required this.onToggleCalendar,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
    required this.onAdd,
    required this.onOpenSettings,
    super.key,
  });

  final DateTime visibleMonth;
  final bool monthExpanded;
  final bool showToday;
  final VoidCallback onToggleCalendar;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAdd;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Daily.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontFamily: 'serif',
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: monthExpanded ? '收起月历' : '展开月历',
                child: TextButton(
                  key: const Key('calendar-view-toggle'),
                  onPressed: onToggleCalendar,
                  style: TextButton.styleFrom(
                    foregroundColor: context.palette.ink,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: MotionSwitcher(
                          alignment: Alignment.centerLeft,
                          offset: const Offset(0, 0.12),
                          child: Text(
                            key: ValueKey<String>(
                              'month-label-${dayKey(visibleMonth)}',
                            ),
                            '${visibleMonth.year} 年 ${visibleMonth.month} 月',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: monthExpanded ? 0.5 : 0,
                        duration: appMotion(context, 220),
                        curve: Curves.easeOutCubic,
                        child: const Icon(Icons.expand_more_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showToday)
              TextButton(
                key: const Key('calendar-today-button'),
                onPressed: onToday,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: context.palette.pine,
                ),
                child: const Text('今天'),
              ),
            _CompactPeriodButton(
              icon: Icons.chevron_left_rounded,
              label: monthExpanded ? '上个月' : '上一周',
              onPressed: onPrevious,
            ),
            _CompactPeriodButton(
              icon: Icons.chevron_right_rounded,
              label: monthExpanded ? '下个月' : '下一周',
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactPeriodButton extends StatelessWidget {
  const _CompactPeriodButton({
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

class CalendarDates extends StatelessWidget {
  const CalendarDates({
    required this.expanded,
    required this.visibleMonth,
    required this.selectedDate,
    required this.statusFor,
    required this.onSelected,
    super.key,
  });

  final bool expanded;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Color? Function(DateTime) statusFor;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = _weekStart(expanded ? first : selectedDate);
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
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expanded ? 42 : 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 52,
          ),
          itemBuilder: (context, index) {
            final date = DateTime(
              gridStart.year,
              gridStart.month,
              gridStart.day + index,
            );
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
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Semantics(
      button: true,
      selected: selected,
      label: '${date.month} 月 ${date.day} 日${isToday ? '，今天' : ''}',
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
                color: selected ? context.palette.pine : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !selected
                    ? Border.all(color: context.palette.pine, width: 1.3)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: selected
                      ? context.palette.pineInk
                      : isToday
                      ? context.palette.pine
                      : inMonth
                      ? context.palette.ink
                      : context.palette.mutedLight,
                  fontSize: 15,
                  fontWeight: selected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
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
        color: context.palette.canvasRaised,
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
              color: context.palette.muted,
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
    this.onEditTime,
    super.key,
  });

  final DayTaskGroup group;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final ValueChanged<ReminderTime> onToggleCompletion;
  final ValueChanged<ReminderTime>? onEditTime;

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
          color: context.palette.completionFill,
          borderRadius: BorderRadius.circular(AppRadii.large),
          elevation: parentCompleted ? 0 : 1,
          shadowColor: context.palette.pine.withValues(alpha: 0.13),
          clipBehavior: Clip.antiAlias,
          child: CompletionFillSurface(
            completed: parentCompleted,
            baseColor: context.palette.completionFill,
            completedColor: context.palette.parentNote,
            borderRadius: BorderRadius.circular(AppRadii.large),
            child: InkWell(
              key: ValueKey<String>('task-${group.item.id}'),
              onTap: isMultiple ? onToggleExpanded : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 66),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 4),
                  child: Row(
                    children: [
                      DailyItemIcon(
                        group.item.iconKey,
                        color: parentCompleted
                            ? context.palette.muted
                            : context.palette.pine,
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
                                        ? context.palette.muted
                                        : context.palette.ink,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            if (onlyTime == null) ...[
                              Text(
                                parentCompleted
                                    ? '当天已完成'
                                    : '下一次 ${group.item.times.where((time) => !group.isCompleted(time)).first.label} · 剩 ${group.item.times.length - group.completedCount} 次',
                                key: ValueKey<String>(
                                  'next-time-${group.item.id}',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: parentCompleted
                                          ? context.palette.muted
                                          : context.palette.pine,
                                    ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  courseDetailsLabel(group.item),
                                  key: ValueKey<String>(
                                    'course-details-${group.item.id}',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (onlyTime != null)
                                  _TimeEditChip(
                                    key: ValueKey<String>(
                                      'quick-time-${group.item.id}-${onlyTime.id}',
                                    ),
                                    time: onlyTime,
                                    compact: true,
                                    minHeight: 32,
                                    onTap: onEditTime == null
                                        ? null
                                        : () => onEditTime!(onlyTime),
                                  ),
                              ],
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
                                          ? context.palette.missed
                                          : context.palette.pine,
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
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: parentCompleted
                                    ? context.palette.muted
                                    : context.palette.ink,
                              ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: context.palette.muted,
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
        ),
        MotionReveal(
          visible: expanded,
          child: DoseRail(
            group: group,
            onToggleCompletion: onToggleCompletion,
            onEditTime: onEditTime,
          ),
        ),
      ],
    );
  }
}

class DoseRail extends StatelessWidget {
  const DoseRail({
    required this.group,
    required this.onToggleCompletion,
    this.onEditTime,
    super.key,
  });

  final DayTaskGroup group;
  final ValueChanged<ReminderTime> onToggleCompletion;
  final ValueChanged<ReminderTime>? onEditTime;

  @override
  Widget build(BuildContext context) {
    final times = group.orderedTimes;
    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textTheme = Theme.of(context).textTheme;
          Size measure(String text, TextStyle? style, double width) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: math.max(1, width));
            final size = painter.size;
            painter.dispose();
            return size;
          }

          var extent = 58.0;
          final stackedRows = <ReminderTime, bool>{};
          for (final time in times) {
            final label = measure(
              time.label,
              const TextStyle(fontSize: 13),
              double.infinity,
            );
            final sequenceWidth = measure(
              '第 ${time.sortOrder + 1} 次',
              textTheme.bodyLarge,
              double.infinity,
            ).width;
            final stacked =
                constraints.maxWidth - 28 <
                14 +
                    sequenceWidth +
                    label.width +
                    (onEditTime == null ? 16 : 52) +
                    4 +
                    48;
            stackedRows[time] = stacked;
            final sequence = measure(
              '第 ${time.sortOrder + 1} 次',
              textTheme.bodyLarge,
              stacked
                  ? constraints.maxWidth - 28 - 14 - 8 - 48
                  : constraints.maxWidth -
                        28 -
                        14 -
                        label.width -
                        (onEditTime == null ? 16 : 52) -
                        4 -
                        48,
            );
            extent = math.max(
              extent,
              stacked
                  ? math.max(48, sequence.height) +
                        4 +
                        math.max(44, label.height) +
                        16
                  : math.max(label.height, sequence.height),
            );
          }
          return Stack(
            children: [
              Positioned(
                left: 10,
                top: 0,
                bottom: 13,
                child: Container(width: 1, color: context.palette.mutedLight),
              ),
              MotionReorderColumn(
                extent: extent,
                children: [
                  for (var index = 0; index < times.length; index++)
                    DoseRow(
                      key: ValueKey<String>('dose-${times[index].id}'),
                      time: times[index],
                      sequence: times[index].sortOrder + 1,
                      completed: group.isCompleted(times[index]),
                      stacked: stackedRows[times[index]]!,
                      onPressed: () => onToggleCompletion(times[index]),
                      onEditTime: onEditTime == null
                          ? null
                          : () => onEditTime!(times[index]),
                    ),
                ],
              ),
            ],
          );
        },
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
    this.onEditTime,
    this.stacked = false,
    super.key,
  });

  final ReminderTime time;
  final int sequence;
  final bool completed;
  final VoidCallback onPressed;
  final VoidCallback? onEditTime;
  final bool stacked;

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
                    ? context.palette.mutedLight
                    : context.palette.statusSage,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: CompletionFillSurface(
            completed: completed,
            baseColor: context.palette.completionFill,
            completedColor: context.palette.parentNote,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: stacked
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '第 $sequence 次',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: completed
                                            ? context.palette.muted
                                            : context.palette.ink,
                                      ),
                                ),
                              ),
                              CompletionButton(
                                completed: completed,
                                onPressed: onPressed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _TimeEditChip(
                            time: time,
                            onTap: onEditTime,
                            compact: true,
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '第 $sequence 次',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: completed
                                      ? context.palette.muted
                                      : context.palette.ink,
                                ),
                          ),
                        ),
                        _TimeEditChip(time: time, onTap: onEditTime),
                        const SizedBox(width: 4),
                        CompletionButton(
                          completed: completed,
                          onPressed: onPressed,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeEditChip extends StatelessWidget {
  const _TimeEditChip({
    required this.time,
    this.onTap,
    this.compact = false,
    this.minHeight = 44,
    super.key,
  });

  final ReminderTime time;
  final VoidCallback? onTap;
  final bool compact;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: onTap == null ? null : '修改 ${time.label} 提醒时间',
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTap != null && !compact) ...[
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: context.palette.pine,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  time.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.pine,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.edit_outlined,
                    size: 12,
                    color: context.palette.muted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
            painter: _CompletionPainter(_progress, context.palette),
          ),
        ),
      ),
    );
  }
}

class _CompletionPainter extends CustomPainter {
  _CompletionPainter(this.progress, this.colors) : super(repaint: progress);

  final Animation<double> progress;
  final DailyColors colors;

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
      canvas.drawCircle(center, 12.5 * fill, Paint()..color = colors.pine);
    }
    canvas.drawCircle(
      center,
      11.75,
      Paint()
        ..color = Color.lerp(colors.muted, colors.pine, fill)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    if (check > 0) {
      canvas.drawPath(
        _checkMetric.extractPath(0, _checkMetric.length * check),
        Paint()
          ..color = colors.pineInk
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
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}

class EmptyDayState extends StatelessWidget {
  const EmptyDayState({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.rule),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            color: context.palette.muted,
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
            color: index.isEven
                ? context.palette.parentNote
                : context.palette.field,
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
        ),
      ),
    );
  }
}

class _EditableTime {
  _EditableTime({this.id, required this.minuteOfDay, Object? token})
    : token = token ?? Object();

  final int? id;
  final int minuteOfDay;
  final Object token;

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
    if (picked == null || !mounted) return;
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
    if (picked == null || !mounted) return;
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
      _times[index] = _EditableTime(
        id: current.id,
        minuteOfDay: minuteOfDay,
        token: current.token,
      );
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
      backgroundColor: context.palette.canvasRaised,
      barrierColor: context.palette.ink.withValues(alpha: 0.26),
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
    FocusScope.of(context).unfocus();
    if (_validateStock(_stockController.text) != null ||
        _validateDose(_doseController.text) != null ||
        _invalidInventoryDates) {
      await _showMoreSettings(showErrors: true);
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

  String get _repeatSummary => switch (_repeatKind) {
    RepeatKind.daily => '每天',
    RepeatKind.interval => '每 $_intervalDays 天',
    RepeatKind.weekly =>
      _weekdays.isEmpty
          ? '请选择星期'
          : '每周${(_weekdays.toList()..sort()).map((day) => const ['一', '二', '三', '四', '五', '六', '日'][day - 1]).join('、')}',
  };

  String get _dateSummary {
    final start = _startDate == dateOnly(DateTime.now())
        ? '今天起'
        : '${_startDate.month}/${_startDate.day} 起';
    return '$start · ${_endDate == null ? '长期' : '${_endDate!.month}/${_endDate!.day} 结束'}';
  }

  String get _timeSummary => _times.length == 1
      ? _times.first.label
      : '${_times.first.label} 等 ${_times.length} 个时间';

  String get _settingsSummary {
    final settings = <String>[
      if (_stockController.text.trim().isNotEmpty) '已设置库存',
      if (_productionDate != null || _expiryDate != null) '已设置保质期',
      if (_snoozeEnabled) '稍后 $_snoozeMinutes 分钟提醒',
      if (_endDate != null && (_alertMonthBefore || _alertWeekBefore))
        '周期结束前提醒',
    ];
    return settings.isEmpty ? '库存、保质期与提醒规则' : settings.join(' · ');
  }

  static String? _validateStock(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = double.tryParse(value.trim());
    return amount == null ||
            !amount.isFinite ||
            amount < 0 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim())
        ? '请输入不小于 0 的数字'
        : null;
  }

  static String? _validateDose(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    return amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim())
        ? '请输入大于 0 的数字'
        : null;
  }

  bool get _invalidInventoryDates =>
      _productionDate != null &&
      _expiryDate != null &&
      _expiryDate!.isBefore(_productionDate!);

  Future<void> _showEditorSheet({
    required String title,
    required Widget Function(BuildContext, StateSetter) content,
    bool Function()? validate,
  }) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.canvasRaised,
      barrierColor: context.palette.ink.withValues(alpha: 0.26),
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      sheetAnimationStyle: AnimationStyle(
        duration: appMotion(context, 280),
        reverseDuration: appMotion(context, 220),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  160,
                  MediaQuery.sizeOf(context).height * .84 - keyboard,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭设置',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 21),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                        child: content(context, refresh),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                      child: FilledButton(
                        key: const Key('editor-sheet-done'),
                        onPressed: () {
                          if (validate != null && !validate()) {
                            refresh(() {});
                            return;
                          }
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(elevation: 0),
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshSheetAfter(
    BuildContext context,
    StateSetter refresh,
    Future<void> Function() action,
  ) async {
    await action();
    if (context.mounted) refresh(() {});
  }

  Future<void> _showRepeatSettings() => _showEditorSheet(
    title: '重复方式',
    validate: () => _repeatKind != RepeatKind.weekly || _weekdays.isNotEmpty,
    content: (context, refresh) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<RepeatKind>(
          segments: const [
            ButtonSegment(value: RepeatKind.daily, label: Text('每天')),
            ButtonSegment(value: RepeatKind.weekly, label: Text('每周')),
            ButtonSegment(value: RepeatKind.interval, label: Text('隔几天')),
          ],
          selected: {_repeatKind},
          onSelectionChanged: (value) {
            setState(() {
              _repeatKind = value.single;
              if (_intervalDays < 2) _intervalDays = 2;
            });
            refresh(() {});
            HapticFeedback.selectionClick();
          },
        ),
        const SizedBox(height: 16),
        if (_repeatKind == RepeatKind.weekly) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(7, (index) {
              final day = index + 1;
              return FilterChip(
                key: ValueKey<String>('editor-weekday-$day'),
                label: Text(const ['一', '二', '三', '四', '五', '六', '日'][index]),
                selected: _weekdays.contains(day),
                showCheckmark: false,
                onSelected: (selected) {
                  setState(() {
                    selected ? _weekdays.add(day) : _weekdays.remove(day);
                  });
                  refresh(() {});
                  HapticFeedback.selectionClick();
                },
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '每周至少选择一天',
            style: TextStyle(
              fontSize: 12,
              color: _weekdays.isEmpty
                  ? context.palette.missed
                  : context.palette.muted,
            ),
          ),
        ] else ...[
          _EditorSurface(
            child: _EditorSettingRow(
              icon: Icons.repeat_rounded,
              label: '频率与次数',
              value: _frequencyLabel,
              onTap: () => _refreshSheetAfter(context, refresh, _pickFrequency),
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _showTimeSettings() => _showEditorSheet(
    title: '提醒时间',
    content: (context, refresh) => _EditorSurface(
      child: Column(
        children: [
          _EditorSettingRow(
            key: const Key('frequency-picker-row'),
            icon: Icons.repeat_rounded,
            label: '提醒频率',
            value: _frequencyLabel,
            onTap: () => _refreshSheetAfter(context, refresh, _pickFrequency),
          ),
          const Divider(indent: 46, endIndent: 16),
          for (var index = 0; index < _times.length; index++) ...[
            _EditorSettingRow(
              key: ValueKey<String>('editor-time-$index'),
              icon: Icons.schedule_rounded,
              label: _times.length == 1 ? '时间' : '第 ${index + 1} 次',
              value: _times[index].label,
              onTap: () =>
                  _refreshSheetAfter(context, refresh, () => _pickTime(index)),
            ),
            if (index < _times.length - 1)
              const Divider(indent: 46, endIndent: 16),
          ],
        ],
      ),
    ),
  );

  Future<void> _showDateSettings() => _showEditorSheet(
    title: '日期范围',
    content: (context, refresh) => _EditorSurface(
      child: Column(
        children: [
          _EditorSettingRow(
            icon: Icons.calendar_today_outlined,
            label: '开始日期',
            value: yearDate(_startDate),
            onTap: () => _refreshSheetAfter(context, refresh, _pickStartDate),
          ),
          const Divider(indent: 46, endIndent: 16),
          _EditorSettingRow(
            icon: Icons.event_available_outlined,
            label: '结束日期',
            value: _endDate == null ? '长期' : yearDate(_endDate!),
            onTap: () => _refreshSheetAfter(context, refresh, _pickEndDate),
            trailing: _endDate == null
                ? null
                : IconButton(
                    tooltip: '设为长期',
                    onPressed: () {
                      setState(() => _endDate = null);
                      refresh(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ],
      ),
    ),
  );

  Future<void> _showMoreSettings({bool showErrors = false}) async {
    final formKey = GlobalKey<FormState>();
    await _showEditorSheet(
      title: '更多设置',
      validate: () =>
          (formKey.currentState?.validate() ?? true) && !_invalidInventoryDates,
      content: (context, refresh) => Form(
        key: formKey,
        autovalidateMode: showErrors
            ? AutovalidateMode.always
            : AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EditorSectionLabel('库存与用量'),
            const SizedBox(height: 6),
            Text(
              '按实际完成次数扣减，录入数量留空则不统计',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
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
                    validator: _validateStock,
                    onChanged: (_) => setState(() {}),
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
                    validator: _validateDose,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('stock-unit-field'),
              initialValue: _stockUnit,
              decoration: const InputDecoration(labelText: '单位'),
              items:
                  const [
                        '片',
                        '粒',
                        '支',
                        '袋',
                        '毫升',
                        '滴',
                        '贴',
                        '盒',
                        '次',
                        '分钟',
                        '页',
                      ]
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
              const SizedBox(height: 10),
              Text(
                '已记录使用 ${quantityLabel(widget.item!.usedQuantity)} $_stockUnit；修改录入数量后，历史消耗仍保留',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 22),
            const _EditorSectionLabel('保质期'),
            const SizedBox(height: 8),
            _EditorSurface(
              child: Column(
                children: [
                  _EditorSettingRow(
                    icon: Icons.factory_outlined,
                    label: '生产日期',
                    value: _productionDate == null
                        ? '未填写'
                        : yearDate(_productionDate!),
                    onTap: () => _refreshSheetAfter(
                      context,
                      refresh,
                      _pickProductionDate,
                    ),
                    trailing: _productionDate == null
                        ? null
                        : IconButton(
                            tooltip: '清除生产日期',
                            onPressed: () {
                              setState(() => _productionDate = null);
                              refresh(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                  const Divider(indent: 46, endIndent: 16),
                  _EditorSettingRow(
                    icon: Icons.event_busy_outlined,
                    label: '有效期至',
                    value: _expiryDate == null ? '未填写' : yearDate(_expiryDate!),
                    onTap: () =>
                        _refreshSheetAfter(context, refresh, _pickExpiryDate),
                    trailing: _expiryDate == null
                        ? null
                        : IconButton(
                            tooltip: '清除有效期',
                            onPressed: () {
                              setState(() => _expiryDate = null);
                              refresh(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ],
              ),
            ),
            if (_invalidInventoryDates)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '有效期不能早于生产日期',
                  style: TextStyle(color: context.palette.missed),
                ),
              ),
            const SizedBox(height: 22),
            const _EditorSectionLabel('提醒规则'),
            const SizedBox(height: 8),
            _EditorSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('稍后再次提醒'),
                    subtitle: const Text('提醒不会替你完成事项'),
                    value: _snoozeEnabled,
                    activeTrackColor: context.palette.pine,
                    onChanged: (value) {
                      setState(() => _snoozeEnabled = value);
                      refresh(() {});
                    },
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
                              onSelected: (_) {
                                setState(() => _snoozeMinutes = minutes);
                                refresh(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                  if (_endDate != null) ...[
                    const Divider(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('结束前一个月提醒'),
                      value: _alertMonthBefore,
                      activeTrackColor: context.palette.pine,
                      onChanged: (value) {
                        setState(() => _alertMonthBefore = value);
                        refresh(() {});
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('结束前一周提醒'),
                      value: _alertWeekBefore,
                      activeTrackColor: context.palette.pine,
                      onChanged: (value) {
                        setState(() => _alertWeekBefore = value);
                        refresh(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _selectIcon(String key) {
    final previous = ItemIcons.categoryFor(_iconKey);
    final selected = ItemIcons.categoryFor(key);
    setState(() {
      _iconKey = key;
      if (widget.item == null &&
          previous != selected &&
          _stockController.text.isEmpty &&
          ((_doseController.text == '1' &&
                  const {'片', '粒', '次'}.contains(_stockUnit)) ||
              (_doseController.text == '250' && _stockUnit == '毫升'))) {
        _stockUnit = switch (selected.key) {
          'water' => '毫升',
          'vitamin' => '粒',
          'medication' => '片',
          _ => '次',
        };
        _doseController.text = selected.key == 'water' ? '250' : '1';
      }
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _showIconSettings() => _showEditorSheet(
    title: '图标与分类',
    content: (context, refresh) {
      final category = ItemIcons.categoryFor(_iconKey);
      void choose(String key) {
        _selectIcon(key);
        refresh(() {});
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ItemCategoryPicker(iconKey: _iconKey, onSelected: choose),
          const SizedBox(height: 22),
          _EditorSectionLabel('${category.label}图标'),
          const SizedBox(height: 10),
          _ItemIconChoices(iconKey: _iconKey, onSelected: choose),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left_rounded, size: 27),
                  ),
                  Expanded(
                    child: Text(
                      widget.item == null ? '新建事项' : '编辑事项',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  key: const Key('item-editor-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  children: [
                    _EditorSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: appMotion(context, 180),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: context.palette.parentNote,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: DailyItemIcon(
                              _iconKey,
                              color: context.palette.pine,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              key: const Key('item-title-field'),
                              controller: _titleController,
                              textInputAction: TextInputAction.done,
                              maxLength: 30,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText: '事项名称',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: context.palette.muted,
                                ),
                                hintText: '例如：维生素 D',
                                hintStyle: TextStyle(
                                  fontSize: 19,
                                  color: context.palette.mutedLight,
                                  fontWeight: FontWeight.w400,
                                ),
                                filled: false,
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? '请填写事项名称'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _EditorSectionLabel('分类'),
                        TextButton(
                          key: const Key('editor-icon-settings'),
                          onPressed: _showIconSettings,
                          child: Text(
                            '${ItemIcons.choiceFor(_iconKey).label} · 更换图标',
                          ),
                        ),
                      ],
                    ),
                    _ItemCategoryPicker(
                      iconKey: _iconKey,
                      onSelected: _selectIcon,
                    ),
                    const SizedBox(height: 20),
                    const _EditorSectionLabel('安排'),
                    const SizedBox(height: 9),
                    _EditorSurface(
                      child: Column(
                        children: [
                          _EditorSettingRow(
                            key: const Key('editor-repeat-settings'),
                            icon: Icons.repeat_rounded,
                            label: '重复',
                            value: _repeatSummary,
                            onTap: _showRepeatSettings,
                          ),
                          const Divider(indent: 46, endIndent: 16),
                          _EditorSettingRow(
                            key: const Key('editor-time-settings'),
                            icon: Icons.schedule_rounded,
                            label: '提醒时间',
                            value: _timeSummary,
                            onTap: _showTimeSettings,
                          ),
                          const Divider(indent: 46, endIndent: 16),
                          _EditorSettingRow(
                            key: const Key('editor-date-settings'),
                            icon: Icons.calendar_today_outlined,
                            label: '日期范围',
                            value: _dateSummary,
                            onTap: _showDateSettings,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EditorSurface(
                      child: InkWell(
                        key: const Key('editor-more-settings'),
                        onTap: _showMoreSettings,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 17,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 21,
                                color: context.palette.muted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '更多设置',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _settingsSummary,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: context.palette.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    key: const Key('save-item-button'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.palette.pineInk,
                            ),
                          )
                        : Icon(
                            widget.item == null
                                ? Icons.add_rounded
                                : Icons.check_rounded,
                            size: 20,
                          ),
                    label: Text(
                      _saving
                          ? '正在保存'
                          : widget.item == null
                          ? '创建事项'
                          : '保存修改',
                    ),
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

class _ItemCategoryPicker extends StatelessWidget {
  const _ItemCategoryPicker({required this.iconKey, required this.onSelected});
  final String iconKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => GridView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      mainAxisExtent: 64 + MediaQuery.textScalerOf(context).scale(12) - 12,
    ),
    children: [
      for (final category in ItemIcons.categories)
        _ItemIconTile(
          key: ValueKey('icon-${category.key}'),
          iconKey: category.defaultIconKey,
          label: category.label,
          selected: ItemIcons.categoryFor(iconKey) == category,
          onTap: () => onSelected(category.defaultIconKey),
        ),
    ],
  );
}

class _ItemIconChoices extends StatelessWidget {
  const _ItemIconChoices({required this.iconKey, required this.onSelected});
  final String iconKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final choice in ItemIcons.categoryFor(iconKey).choices)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _ItemIconTile(
              key: ValueKey('item-icon-${choice.key}'),
              iconKey: choice.key,
              label: choice.label,
              selected: ItemIcons.choiceFor(iconKey).key == choice.key,
              onTap: () => onSelected(choice.key),
            ),
          ),
        ),
    ],
  );
}

class _ItemIconTile extends StatelessWidget {
  const _ItemIconTile({
    required this.iconKey,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String iconKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected
          ? context.palette.parentNote
          : context.palette.canvasRaised,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              DailyItemIcon(
                iconKey,
                size: 24,
                color: selected ? context.palette.pine : context.palette.muted,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? context.palette.pine
                      : context.palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EditorSurface extends StatelessWidget {
  const _EditorSurface({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.canvasRaised,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class _EditorSectionLabel extends StatelessWidget {
  const _EditorSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: context.palette.muted,
      ),
    ),
  );
}

class _EditorSettingRow extends StatelessWidget {
  const _EditorSettingRow({
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, size: 21, color: context.palette.muted),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.pine,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 7),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: context.palette.muted,
                ),
          ],
        ),
      ),
    ),
  );
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
      color: context.palette.field,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.palette.rule),
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
              Icon(icon, color: context.palette.muted, size: 22),
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
            color: context.palette.parentNote.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(
              color: context.palette.pine.withValues(alpha: 0.18),
            ),
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
                color: selected ? context.palette.pine : context.palette.muted,
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
                      '提醒频率',
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
              ).textTheme.titleMedium?.copyWith(color: context.palette.pine),
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
    required this.onEditTime,
    super.key,
  });

  final DailyStore store;
  final ReminderScheduler scheduler;
  final int revision;
  final VoidCallback onAdd;
  final ValueChanged<ReminderItem> onEdit;
  final VoidCallback onOpenSettings;
  final VoidCallback onDataChanged;
  final void Function(ReminderItem, ReminderTime) onEditTime;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  List<ReminderItem> _items = const [];
  _ItemFilter _filter = _ItemFilter.active;
  bool _loading = true;
  int _loadVersion = 0;

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
    final version = ++_loadVersion;
    final items = await widget.store.loadItems(includeArchived: true);
    if (!mounted || version != _loadVersion) return;
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
        color: context.palette.pine,
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
            MotionSwitcher(
              animateSize: true,
              child: Column(
                key: ValueKey<_ItemFilter>(_filter),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          onEditTime: (time) => widget.onEditTime(item, time),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / _ItemFilter.values.length;
        return Stack(
          children: [
            AnimatedPositioned(
              key: const Key('item-filter-indicator'),
              duration: appMotion(context, 200),
              curve: Curves.easeOutCubic,
              left: selected.index * width,
              width: math.max(0, width - 6),
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palette.parentNote,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                ),
              ),
            ),
            Row(
              children: _ItemFilter.values.map((filter) {
                final active = selected == filter;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton(
                      key: ValueKey<String>('item-filter-${filter.name}'),
                      onPressed: () => onSelected(filter),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: active
                            ? context.palette.ink
                            : context.palette.muted,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                      ),
                      child: Text('${labels[filter]}  ${counts[filter] ?? 0}'),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _ManagementItemCard extends StatelessWidget {
  const _ManagementItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onEditTime,
  });

  final ReminderItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ReminderTime> onEditTime;

  @override
  Widget build(BuildContext context) {
    final ended = item.hasEnded || item.archived;
    final inventoryLabel = inventoryStatusLabel(item);
    final expiryLabel = expiryStatusLabel(item, DateTime.now());
    return Material(
      color: ended
          ? context.palette.completedNote
          : context.palette.canvasRaised,
      borderRadius: BorderRadius.circular(AppRadii.large),
      elevation: ended ? 0 : 1,
      shadowColor: context.palette.pine.withValues(alpha: 0.13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DailyItemIcon(
                item.iconKey,
                color: ended ? context.palette.muted : context.palette.pine,
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
                      ItemIcons.showsDose(item.iconKey) ||
                              item.stockQuantity != null
                          ? '${item.scheduleLabel} · ${courseDetailsLabel(item)}'
                          : courseDetailsLabel(item),
                      maxLines: 2,
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
                              ? context.palette.missed
                              : context.palette.pine,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.times
                          .map(
                            (time) => _TimeEditChip(
                              key: ValueKey<String>(
                                'management-time-${item.id}-${time.id}',
                              ),
                              time: time,
                              onTap: () => onEditTime(time),
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
          Icon(
            Icons.format_list_bulleted_rounded,
            size: 32,
            color: context.palette.muted,
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
    this.diagnosticsOnly = false,
    super.key,
  });

  final DailyStore store;
  final ReminderScheduler scheduler;
  final int revision;
  final bool diagnosticsOnly;

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

  Future<void> _openDiagnostics() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          store: widget.store,
          scheduler: widget.scheduler,
          revision: widget.revision,
          diagnosticsOnly: true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _showLocalData() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.palette.canvasRaised,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本机数据', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DataFigure(value: '$_itemCount', label: '事项'),
              ),
              Expanded(
                child: _DataFigure(value: '$_completionCount', label: '完成记录'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '事项和完成记录保存在这台设备上。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  Widget _buildOverview(BuildContext context) {
    final theme = DailyThemeScope.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            PageTopBar(title: '设置', onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 24),
            const _EditorSectionLabel('外观'),
            const SizedBox(height: 9),
            _EditorSurface(
              child: _SettingsRow(
                key: const Key('settings-theme-color'),
                icon: Icons.palette_outlined,
                title: '主题颜色',
                value: (theme?.color ?? DailyThemeColor.sage).label,
                leadingColor: context.palette.pine,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const ThemeColorPage()),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const _EditorSectionLabel('提醒'),
            const SizedBox(height: 9),
            _EditorSurface(
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: '通知设置',
                    value: _reminderHealth == null
                        ? '读取中'
                        : _reminderHealth!.notificationsEnabled
                        ? '已开启'
                        : '未开启',
                    onTap: () async {
                      if (_reminderHealth?.notificationsEnabled == true) {
                        await widget.scheduler.openNotificationSettings();
                      } else {
                        await _requestPermission();
                      }
                    },
                  ),
                  const Divider(indent: 50, endIndent: 16),
                  _SettingsRow(
                    icon: Icons.notification_add_outlined,
                    title: '发送测试提醒',
                    onTap: _testNotification,
                  ),
                  const Divider(indent: 50, endIndent: 16),
                  _SettingsRow(
                    key: const Key('settings-reminder-help'),
                    icon: Icons.help_outline_rounded,
                    title: '提醒收不到？',
                    onTap: _openDiagnostics,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const _EditorSectionLabel('数据'),
            const SizedBox(height: 9),
            _EditorSurface(
              child: _SettingsRow(
                icon: Icons.storage_rounded,
                title: '本机数据',
                subtitle: '$_itemCount 个事项 · $_completionCount 条完成记录',
                onTap: _showLocalData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.diagnosticsOnly
      ? _buildDiagnostics(context)
      : _buildOverview(context);

  Widget _buildDiagnostics(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            PageTopBar(
              title: '提醒检查',
              onBack: () => Navigator.of(context).pop(),
            ),
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
                  if (!isIOS) ...[
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
                  ],
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    minTileHeight: 58,
                    leading: Icon(
                      _reminderHealth?.reminderChannelCanPopUp == true
                          ? Icons.mark_chat_unread_outlined
                          : Icons.comments_disabled_outlined,
                    ),
                    title: Text(isIOS ? '通知横幅' : '提醒弹窗渠道'),
                    subtitle: Text(
                      _reminderHealth == null
                          ? '正在读取状态'
                          : isIOS
                          ? (_reminderHealth!.reminderChannelCanPopUp
                                ? '已允许横幅，显示方式由系统通知设置与专注模式控制'
                                : '横幅未开启，可在系统通知设置中调整')
                          : !_reminderHealth!.reminderChannelEnabled
                          ? '渠道已关闭'
                          : _reminderHealth!.reminderChannelCanPopUp
                          ? '高优先级，可显示顶部提醒'
                          : '当前可能只在通知栏静默显示',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.scheduler.openNotificationSettings,
                  ),
                  if (!isIOS) ...[
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
                  ],
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
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
    this.leadingColor,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final Color? leadingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 62,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    leading: Icon(icon, size: 23, color: leadingColor ?? context.palette.muted),
    title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null) ...[
          Text(value!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
        ],
        Icon(
          Icons.chevron_right_rounded,
          size: 21,
          color: context.palette.mutedLight,
        ),
      ],
    ),
    onTap: onTap,
  );
}

class ThemeColorPage extends StatelessWidget {
  const ThemeColorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DailyThemeScope.maybeOf(context);
    final selected = controller?.color ?? DailyThemeColor.sage;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            PageTopBar(
              title: '主题颜色',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) => GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth < 310 ? 1 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent:
                      190 + MediaQuery.textScalerOf(context).scale(20) - 20,
                ),
                children: [
                  for (final option in DailyThemeColor.values)
                    _ThemeColorTile(
                      color: option,
                      selected: selected == option,
                      onTap: controller == null
                          ? null
                          : () async {
                              HapticFeedback.selectionClick();
                              final saved = await controller.select(option);
                              if (!saved && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('主题颜色没有保存，请重试')),
                                );
                              }
                            },
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

class _ThemeColorTile extends StatelessWidget {
  const _ThemeColorTile({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final DailyThemeColor color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DailyColors.forTheme(color);
    return Semantics(
      button: true,
      selected: selected,
      label: '${color.label}主题',
      child: Material(
        color: context.palette.canvasRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? context.palette.pine : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('theme-color-${color.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.canvas,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Theme(
                        data: Theme.of(context).copyWith(extensions: [colors]),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ThemeSampleRow(colors: colors, completed: false),
                            const SizedBox(height: 7),
                            _ThemeSampleRow(colors: colors, completed: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        color.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected
                          ? context.palette.pine
                          : context.palette.rule,
                      size: 22,
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

class _ThemeSampleRow extends StatelessWidget {
  const _ThemeSampleRow({required this.colors, required this.completed});
  final DailyColors colors;
  final bool completed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: completed ? colors.parentNote : colors.completionFill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          DailyItemIcon(
            completed ? 'vitamin' : 'medication',
            size: 18,
            color: colors.pine,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: colors.pine.withValues(alpha: completed ? .3 : .55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            completed ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 12,
            color: colors.pine,
          ),
        ],
      ),
    ),
  );
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
      color: transparent ? Colors.transparent : context.palette.field,
      shape: const CircleBorder(),
      elevation: transparent ? 0 : 1,
      shadowColor: context.palette.pine.withValues(alpha: 0.14),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: context.palette.ink, size: 24),
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
        decoration: BoxDecoration(
          color: context.palette.canvas,
          border: Border(top: BorderSide(color: context.palette.rule)),
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
    final color = selected ? context.palette.pine : context.palette.muted;
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
                  color: selected
                      ? context.palette.parentNote
                      : Colors.transparent,
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
