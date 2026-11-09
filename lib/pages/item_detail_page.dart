import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../app.dart' show ItemEditorPage, quantityLabel, yearDate;
import '../widgets/item_icon.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({
    required this.store,
    required this.item,
    required this.onChanged,
    super.key,
  });
  final DailyStore store;
  final ReminderItem item;
  final Future<void> Function() onChanged;
  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late ReminderItem item = widget.item;
  List<OccurrenceRecord> records = [];
  List<DayTaskGroup> today = [];
  List<Map<String, Object?>> pauses = [];
  bool loading = true;
  bool busy = false;
  int recordLimit = 50;
  OccurrenceStatus? filter;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.store.loadItems(includeArchived: true);
    final history = await widget.store.history.loadItemHistory(item.id!);
    final pauseList = (await widget.store.loadJournal(
      'pauses',
    )).values.where((p) => p['itemId'] == item.id).toList();
    if (!mounted) return;
    setState(() {
      item = items.where((i) => i.id == item.id).firstOrNull ?? item;
      records = history.records;
      today = history.today;
      pauses = pauseList;
      loading = false;
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await widget.onChanged();
      await _load();
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作未能完成，请重试')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pause() async {
    final today = dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      helpText: '选择暂停日期（含结束当天）',
      initialDateRange: DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 6)),
      ),
    );
    if (range == null || !mounted) return;
    final note = await askNote(context, title: '暂停备注', hint: '例如：外出一周，可不填写');
    if (note == null) return;
    await _mutate(
      () => widget.store.history.pause(item, range.start, range.end, note),
    );
  }

  Future<void> _editNote() async {
    final note = await askNote(context, title: '事项备注', initial: item.note);
    if (note != null) {
      await _mutate(() => widget.store.saveItem(item.copyWith(note: note)));
    }
  }

  Future<void> _editSchedule() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemEditorPage(store: widget.store, item: item),
      ),
    );
    if (saved == true) {
      await widget.onChanged();
      await _load();
    }
  }

  Future<void> _manage(String action, bool paused) async {
    switch (action) {
      case 'edit':
        await _editSchedule();
      case 'pause':
        if (paused) {
          await _mutate(() => widget.store.history.resume(item));
        } else {
          await _pause();
        }
      case 'archive':
        await _mutate(
          () => widget.store.saveItem(item.copyWith(archived: !item.archived)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentDay = dayKey(now);
    final paused = pauses.any((p) => pauseCoversDate(p, item.id!, now));
    final counts = {
      for (final status in [
        OccurrenceStatus.completed,
        OccurrenceStatus.missed,
        OccurrenceStatus.skipped,
        OccurrenceStatus.paused,
      ])
        status: records.where((r) => r.status == status).length,
    };
    // Today's occurrences have their own section; a selected statistic shows
    // every matching record, including today, in one chronological list.
    final shown = records
        .where(
          (r) => filter == null
              ? dayKey(r.date) != currentDay
              : r.status == filter,
        )
        .toList();
    final visible = shown.take(recordLimit).toList();
    final grouped = <String, List<OccurrenceRecord>>{};
    for (final record in visible) {
      (grouped[dayKey(record.date)] ??= []).add(record);
    }
    final dayRecords = [
      for (final group in today)
        for (final time in group.item.times)
          group.recordFor(time) ??
              OccurrenceRecord(
                item: group.item,
                time: time,
                date: group.date,
                status: group.statusFor(time),
                changedAt: now,
              ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left_rounded, size: 27),
                  ),
                  Expanded(
                    child: Text(
                      '事项详情',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '管理事项',
                    enabled: !busy,
                    onSelected: (action) => _manage(action, paused),
                    icon: const Icon(Icons.more_horiz_rounded),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('修改长期安排')),
                      if (!item.archived)
                        PopupMenuItem(
                          value: 'pause',
                          child: Text(paused ? '提前恢复' : '暂停一段时间'),
                        ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(item.archived ? '恢复事项' : '归档事项'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const PageStorageKey('item-detail-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _overview(paused),
                  const SizedBox(height: 24),
                  _DetailSectionHeading(
                    title: '记录概览',
                    trailing: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message: '漏做在次日生成；跳过和暂停按原计划的每一次计数。轻点统计可筛选记录。',
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: context.palette.mutedLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DetailStatistics(
                    counts: counts,
                    selected: filter,
                    onSelected: (status) => setState(() {
                      filter = filter == status ? null : status;
                      recordLimit = 50;
                    }),
                  ),
                  if (filter == null) ...[
                    const SizedBox(height: 24),
                    _DetailSectionHeading(
                      title: '今日安排',
                      trailing: Text(
                        '${dayRecords.where((r) => r.status == OccurrenceStatus.completed).length} / ${dayRecords.length} 已完成',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DetailSurface(
                      child: dayRecords.isEmpty
                          ? _emptyMessage(loading ? '正在读取安排' : '今天没有安排')
                          : _recordList(dayRecords),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _DetailSectionHeading(
                    title: filter == null ? '逐次记录' : '${filter!.label}记录',
                    trailing: filter == null
                        ? Text(
                            '${shown.length} 条',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : TextButton(
                            onPressed: () => setState(() {
                              filter = null;
                              recordLimit = 50;
                            }),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            child: const Text('查看全部'),
                          ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2),
                  ] else if (shown.isEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailSurface(
                      child: _emptyMessage(
                        filter == null ? '还没有历史记录' : '暂无对应记录',
                      ),
                    ),
                  ] else ...[
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                        child: Text(
                          _recordDate(parseDay(entry.key), now),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      _DetailSurface(child: _recordList(entry.value)),
                    ],
                    if (shown.length > recordLimit)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: () => setState(() => recordLimit += 50),
                          child: const Text('显示更多记录'),
                        ),
                      ),
                  ],
                  if (pauses.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _pauseHistory(now),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview(bool paused) {
    final status = item.archived
        ? '已归档'
        : paused
        ? '暂停中'
        : item.hasEnded
        ? '已结束'
        : '进行中';
    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: context.palette.parentNote,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DailyItemIcon(
                        item.iconKey,
                        size: 28,
                        color: context.palette.pine,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${item.scheduleLabel} · 当天 ${item.times.length} 次',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DetailBadge(
                      label: status,
                      color: item.archived || item.hasEnded
                          ? context.palette.muted
                          : paused
                          ? context.palette.warning
                          : context.palette.pine,
                    ),
                    Text(
                      item.endDate == null
                          ? '长期安排'
                          : '至 ${yearDate(item.endDate!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.stockQuantity != null)
                      Text(
                        '剩余 ${quantityLabel(item.remainingQuantity!)} ${item.stockUnit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          _detailDivider(),
          InkWell(
            onTap: busy ? null : _editNote,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 18,
                    color: context.palette.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '备注',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.note.isEmpty ? '添加事项说明' : item.note,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: item.note.isEmpty
                                    ? context.palette.mutedLight
                                    : context.palette.inkSoft,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: context.palette.mutedLight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pauseHistory(DateTime now) => _DetailSurface(
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: Icon(
          Icons.pause_circle_outline_rounded,
          size: 21,
          color: context.palette.muted,
        ),
        title: Text('暂停安排', style: Theme.of(context).textTheme.bodyMedium),
        subtitle: Text(
          '共 ${pauses.length} 段',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          for (final pause in pauses.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${pause['from']} — ${pause['to']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      _DetailBadge(
                        label: pause['resumedOn'] != null
                            ? '已恢复'
                            : pauseCoversDate(pause, item.id!, now)
                            ? '暂停中'
                            : (pause['to'] as String).compareTo(dayKey(now)) < 0
                            ? '已结束'
                            : '待开始',
                        color: context.palette.muted,
                      ),
                    ],
                  ),
                  if ((pause['note'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        pause['note'] as String,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  String _recordDate(DateTime date, DateTime now) {
    final today = dateOnly(now);
    if (date == today) return '今天';
    if (date == today.subtract(const Duration(days: 1))) {
      return '昨天 · ${date.month} 月 ${date.day} 日';
    }
    return date.year == now.year
        ? '${date.month} 月 ${date.day} 日'
        : yearDate(date);
  }

  Widget _recordList(List<OccurrenceRecord> list) => Column(
    children: [
      for (var index = 0; index < list.length; index++) ...[
        if (index > 0) _detailDivider(),
        _recordTile(list[index]),
      ],
    ],
  );

  Widget _detailDivider() => Divider(
    height: 1,
    indent: 18,
    endIndent: 18,
    color: context.palette.rule.withValues(alpha: .5),
  );

  Widget _emptyMessage(String message) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    child: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.palette.mutedLight),
    ),
  );

  Widget _recordTile(OccurrenceRecord record) {
    final color = record.status == OccurrenceStatus.missed
        ? context.palette.missed
        : record.status == OccurrenceStatus.skipped ||
              record.status == OccurrenceStatus.paused
        ? context.palette.muted
        : context.palette.pine;
    final completedTime =
        '${record.changedAt.hour.toString().padLeft(2, '0')}:${record.changedAt.minute.toString().padLeft(2, '0')}';
    final completedLabel = DateUtils.isSameDay(record.changedAt, record.date)
        ? '完成于 $completedTime'
        : '完成于 ${record.changedAt.year == record.date.year ? '${record.changedAt.month}/${record.changedAt.day}' : yearDate(record.changedAt)} $completedTime';
    return InkWell(
      onTap: busy ? null : () => _actions(record),
      onLongPress: busy ? null : () => _actions(record),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_recordIcon(record.status), size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        record.time.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _DetailBadge(label: record.status.label, color: color),
                    ],
                  ),
                  if (record.item.title != item.title)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        record.item.title,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (record.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        record.note,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  if (record.status == OccurrenceStatus.completed)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        completedLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: context.palette.mutedLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _actions(OccurrenceRecord record) async {
    final result = await showOccurrenceActions(context, record);
    if (result == null) return;
    await _mutate(
      () => widget.store.history.setStatus(record, result.$1, note: result.$2),
    );
  }
}

IconData _recordIcon(OccurrenceStatus status) => switch (status) {
  OccurrenceStatus.completed => Icons.check_circle_outline_rounded,
  OccurrenceStatus.missed => Icons.error_outline_rounded,
  OccurrenceStatus.skipped => Icons.skip_next_outlined,
  OccurrenceStatus.paused => Icons.pause_circle_outline_rounded,
  OccurrenceStatus.pending => Icons.radio_button_unchecked_rounded,
};

class _DetailSurface extends StatelessWidget {
  const _DetailSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.canvasRaised,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _DetailSectionHeading extends StatelessWidget {
  const _DetailSectionHeading({required this.title, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    ),
  );
}

class _DetailStatistics extends StatelessWidget {
  const _DetailStatistics({
    required this.counts,
    required this.selected,
    required this.onSelected,
  });
  final Map<OccurrenceStatus, int> counts;
  final OccurrenceStatus? selected;
  final ValueChanged<OccurrenceStatus> onSelected;

  TextSpan _label(BuildContext context, OccurrenceStatus status, int count) =>
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        children: [
          TextSpan(text: '${status.label} '),
          TextSpan(
            text: '$count',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: context.palette.ink,
            ),
          ),
          const TextSpan(text: ' 次'),
        ],
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var minimumWidth = 0.0;
      for (final entry in counts.entries) {
        final painter = TextPainter(
          text: _label(context, entry.key, entry.value),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (painter.width + 52 > minimumWidth) {
          minimumWidth = painter.width + 52;
        }
        painter.dispose();
      }
      final columns = constraints.maxWidth >= minimumWidth * 2 + 1 ? 2 : 1;
      return _DetailSurface(
        child: ColoredBox(
          color: context.palette.rule.withValues(alpha: .4),
          child: GridView(
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: MediaQuery.textScalerOf(context).scale(21) + 38,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
            ),
            children: [
              for (final entry in counts.entries)
                Semantics(
                  button: true,
                  selected: selected == entry.key,
                  label: '${entry.key.label} ${entry.value} 次',
                  onTap: () => onSelected(entry.key),
                  child: ExcludeSemantics(
                    child: Material(
                      color: selected == entry.key
                          ? context.palette.parentNote
                          : context.palette.canvasRaised,
                      child: InkWell(
                        onTap: () => onSelected(entry.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(
                                _recordIcon(entry.key),
                                size: 17,
                                color: entry.key == OccurrenceStatus.missed
                                    ? context.palette.missed
                                    : context.palette.pine,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  _label(context, entry.key, entry.value),
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> askNote(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '可填写原因或说明',
}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(title: title, initial: initial, hint: hint),
  );
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.initial,
    required this.hint,
  });
  final String title, initial, hint;
  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      maxLines: 4,
      maxLength: 500,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('保存'),
      ),
    ],
  );
}

Future<(OccurrenceStatus, String)?> showOccurrenceActions(
  BuildContext context,
  OccurrenceRecord record,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(record.item.title),
          subtitle: Text(
            '${dayKey(record.date)} ${record.time.label} · ${record.status.label}',
          ),
        ),
        if (!record.date.isAfter(dateOnly(DateTime.now())))
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('标记完成'),
            onTap: () => Navigator.pop(ctx, 'complete'),
          ),
        ListTile(
          leading: const Icon(Icons.skip_next_outlined),
          title: const Text('跳过本次'),
          onTap: () => Navigator.pop(ctx, 'skip'),
        ),
        ListTile(
          leading: const Icon(Icons.notes_rounded),
          title: const Text('编辑本次备注'),
          onTap: () => Navigator.pop(ctx, 'note'),
        ),
        if (record.status != OccurrenceStatus.pending)
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('恢复为未完成'),
            onTap: () => Navigator.pop(ctx, 'reset'),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );
  if (action == null || !context.mounted) return null;
  final note = await askNote(
    context,
    title: action == 'skip' ? '跳过本次' : '本次备注',
    initial: record.note,
  );
  if (note == null) return null;
  return (
    switch (action) {
      'complete' => OccurrenceStatus.completed,
      'skip' => OccurrenceStatus.skipped,
      'reset' =>
        record.date.isBefore(dateOnly(DateTime.now()))
            ? OccurrenceStatus.missed
            : OccurrenceStatus.pending,
      _ => record.status,
    },
    note,
  );
}
