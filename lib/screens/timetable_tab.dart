import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../timetable_service.dart';
import '../timetable_loader_service.dart';
import '../subject_alias_service.dart';
import '../models/student_data.dart';
import '../theme.dart';

// ─── Period schedule ──────────────────────────────────────────────────────────

class _PeriodSlot {
  final String label;
  final TimeOfDay start;
  final TimeOfDay end;
  final bool isLunch;
  const _PeriodSlot({required this.label, required this.start, required this.end, this.isLunch = false});

  String get timeRange => '${_fmt(start)} – ${_fmt(end)}';
  static String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}

const List<_PeriodSlot> _kSlots = [
  _PeriodSlot(label: '1st Period', start: TimeOfDay(hour: 9,  minute: 0),  end: TimeOfDay(hour: 9,  minute: 55)),
  _PeriodSlot(label: '2nd Period', start: TimeOfDay(hour: 9,  minute: 55), end: TimeOfDay(hour: 10, minute: 50)),
  _PeriodSlot(label: '3rd Period', start: TimeOfDay(hour: 11, minute: 10), end: TimeOfDay(hour: 12, minute: 5)),
  _PeriodSlot(label: '4th Period', start: TimeOfDay(hour: 12, minute: 5),  end: TimeOfDay(hour: 13, minute: 0)),
  _PeriodSlot(label: 'Lunch Break',start: TimeOfDay(hour: 13, minute: 0),  end: TimeOfDay(hour: 13, minute: 55), isLunch: true),
  _PeriodSlot(label: '6th Period', start: TimeOfDay(hour: 13, minute: 55), end: TimeOfDay(hour: 14, minute: 50)),
  _PeriodSlot(label: '7th Period', start: TimeOfDay(hour: 14, minute: 50), end: TimeOfDay(hour: 15, minute: 40)),
  _PeriodSlot(label: '8th Period', start: TimeOfDay(hour: 15, minute: 40), end: TimeOfDay(hour: 16, minute: 30)),
];

int _toMins(TimeOfDay t) => t.hour * 60 + t.minute;

int _currentSlotIndex(DateTime now) {
  final nowMins = now.hour * 60 + now.minute;
  for (int i = 0; i < _kSlots.length; i++) {
    if (nowMins >= _toMins(_kSlots[i].start) && nowMins < _toMins(_kSlots[i].end)) return i;
  }
  return -1;
}

bool _slotDone(int slotIdx, DateTime now) =>
    now.hour * 60 + now.minute >= _toMins(_kSlots[slotIdx].end);

// ─── Main widget ──────────────────────────────────────────────────────────────

class TimetableTab extends StatefulWidget {
  final StudentData studentData;
  const TimetableTab({Key? key, required this.studentData}) : super(key: key);
  @override
  _TimetableTabState createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> with SingleTickerProviderStateMixin {
  Map<String, List<PeriodEntry>> _timetable = {};
  bool _isLoading = true;
  bool _isEditing = false;
  late TabController _dayTabController;
  Map<String, String> _subjectAliases = {};
  DateTime _now = DateTime.now();
  Timer? _ticker;

  static const _days     = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const _fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  static int _todayIdx() {
    final w = DateTime.now().weekday;
    return (w >= 1 && w <= 5) ? w - 1 : 0;
  }

  bool _isActuallyToday(int dayIndex) {
    final w = DateTime.now().weekday;
    return w == (dayIndex + 1);
  }

  @override
  void initState() {
    super.initState();
    _dayTabController = TabController(length: _days.length, vsync: this, initialIndex: _todayIdx());
    _load();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dayTabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved   = await TimetableService.load();
    final aliases = await SubjectAliasService.load();
    final prefs   = await SharedPreferences.getInstance();


    setState(() {
      _timetable      = saved;
      _subjectAliases = aliases;
      _isLoading      = false;
      _isEditing      = saved.isEmpty;
    });
  }

  Future<void> _save() async {
    await TimetableService.save(_timetable);
    setState(() => _isEditing = false);
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VergeTheme.surfaceSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.08)),
        ),
        title: Text('Reset Timetable',
            style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.hazardWhite)),
        content: Text('This will erase your entire timetable.',
            style: TextStyle(color: VergeTheme.secondaryText, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: VergeTheme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Reset', style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.ultraviolet))),
        ],
      ),
    );
    if (ok == true) {
      await TimetableService.clear();
      setState(() { _timetable = {}; _isEditing = true; });
    }
  }

  void _showAliasConfig() {
    showDialog(
      context: context,
      builder: (ctx) => _SubjectAliasConfigDialog(
        aliases: _subjectAliases,
        attendanceSubjects: _attendanceSubjects,
        onSave: (updated) async {
          await SubjectAliasService.save(updated);
          setState(() => _subjectAliases = updated);
          if (mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  static const String _kBaseUrl = 'https://raw.githubusercontent.com/MailMalone/Attenda-Timetables/main/';

  Future<void> _showAutoloadDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSection = prefs.getString('timetable_autoload_section') ?? '';

    // Priority: saved preference → empty string
    final savedSem = prefs.getString('timetable_autoload_sem') ?? '';

    final sectionCtrl  = TextEditingController(text: savedSection);
    final semesterCtrl = TextEditingController(text: savedSem);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VergeTheme.surfaceSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.08)),
        ),
        title: Text('Autoload Timetable',
            style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.hazardWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your details to fetch your timetable from the official repository.',
              style: TextStyle(color: VergeTheme.secondaryText, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: semesterCtrl,
              style: const TextStyle(color: VergeTheme.hazardWhite),
              keyboardType: TextInputType.number,
              decoration: _inputDeco('Semester (e.g. 2, 5)', Icons.school_rounded),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sectionCtrl,
              style: const TextStyle(color: VergeTheme.hazardWhite),
              decoration: _inputDeco('Section (e.g. A, B, C)', Icons.grid_view_rounded),
              textCapitalization: TextCapitalization.characters,
              autofocus: savedSection.isEmpty,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: VergeTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              if (sectionCtrl.text.trim().isEmpty || semesterCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VergeTheme.jellyMint,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Load', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      final section  = sectionCtrl.text.trim().toUpperCase();
      final semester = semesterCtrl.text.trim();
      await prefs.setString('timetable_autoload_section', section);
      await prefs.setString('timetable_autoload_sem', semester);

      final url = '$_kBaseUrl$semester$section.json';
      _autoloadTimetable(url, semester, section);
    }
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: VergeTheme.secondaryText, fontSize: 13),
        prefixIcon: Icon(icon, color: VergeTheme.secondaryText, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: VergeTheme.jellyMint),
        ),
        filled: true,
        fillColor: VergeTheme.hazardWhite.withValues(alpha: 0.03),
      );

  Future<void> _autoloadTimetable(String url, String semester, String section) async {
    setState(() => _isLoading = true);
    try {
      final updated = await TimetableLoaderService.fetchAndParse(
        url: url,
        semester: semester,
        section: section,
        attendanceSubjects: _attendanceSubjects,
        subjectAliases: _subjectAliases,
      );

      await TimetableService.save(updated);
      setState(() {
        _timetable = updated;
        _isLoading = false;
        _isEditing = false;
      });
      _showSnack('Timetable autoloaded successfully', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Failed to autoload: ${e.toString()}', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? VergeTheme.ultraviolet : VergeTheme.jellyMint,
    ));
  }

  void _addPeriod(String day) => setState(() {
    _timetable[day] = [...(_timetable[day] ?? []),
      const PeriodEntry(subjectCode: '', subjectName: '', alias: '', isPractical: false)];
  });

  void _removePeriod(String day, int i) => setState(() {
    final list = List<PeriodEntry>.from(_timetable[day] ?? []);
    list.removeAt(i);
    _timetable[day] = list;
  });

  void _updatePeriod(String day, int i, PeriodEntry e) {
    final list = List<PeriodEntry>.from(_timetable[day] ?? []);
    list[i] = e;
    _timetable[day] = list;
  }

  List<Map<String, dynamic>> get _attendanceSubjects =>
      widget.studentData.attendance.map((e) => e as Map<String, dynamic>).toList();

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VergeTheme.jellyMint, strokeWidth: 2));
    }
    return Column(children: [
      _buildHeader(),
      _buildDayTabBar(),
      Expanded(
        child: TabBarView(
          controller: _dayTabController,
          children: List.generate(_days.length, (i) => _buildDayView(_days[i], _fullDays[i])),
        ),
      ),
    ]);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)))),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded, color: VergeTheme.jellyMint, size: 16),
        const SizedBox(width: 8),
        const Text('Timetable',
            style: TextStyle(color: VergeTheme.jellyMint, fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        _headerBtn(icon: Icons.cloud_download_rounded, label: 'Autoload',
            color: VergeTheme.jellyMint, onTap: _showAutoloadDialog),
        const SizedBox(width: 8),
      ]),
    );
  }

  Widget _headerBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildDayTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)))),
      child: TabBar(
        controller: _dayTabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: VergeTheme.jellyMint,
        unselectedLabelColor: VergeTheme.dimGray,
        indicatorColor: VergeTheme.jellyMint,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        dividerColor: Colors.transparent,
        tabs: List.generate(_days.length, (i) {
          final isToday = _isActuallyToday(i);
          final hasData = (_timetable[_days[i]] ?? []).isNotEmpty;
          return Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_days[i]),
              const SizedBox(width: 4),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: VergeTheme.jellyMint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Today',
                      style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.jellyMint)),
                )
              else if (hasData)
                Container(width: 5, height: 5,
                    decoration: const BoxDecoration(color: VergeTheme.jellyMint, shape: BoxShape.circle)),
            ]),
          );
        }),
      ),
    );
  }

  // ─── Day view ─────────────────────────────────────────────────────────────

  Widget _buildDayView(String day, String fullDay) {
    final periods    = _timetable[day] ?? [];
    final isToday    = _isActuallyToday(_days.indexOf(day));
    final activeSlot = isToday ? _currentSlotIndex(_now) : -2;

    if (!_isEditing && periods.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_busy_rounded, color: VergeTheme.secondaryText, size: 40),
          const SizedBox(height: 12),
          Text('No classes on $fullDay', style: TextStyle(color: VergeTheme.secondaryText, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Tap Edit to add your schedule', style: TextStyle(color: VergeTheme.secondaryText, fontSize: 12)),
        ]),
      );
    }

    if (_isEditing) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          ...List.generate(periods.length, (i) {
            final slotIdx = i < 4 ? i : i + 1; // skip lunch at slot 4
            final hint = slotIdx < _kSlots.length ? _kSlots[slotIdx].timeRange : '';
            final colors = [
              VergeTheme.jellyMint, const Color(0xFFA78BFA), const Color(0xFF34D399),
              const Color(0xFFFBBF24), const Color(0xFFF87171), const Color(0xFF38BDF8),
              const Color(0xFFE879F9), const Color(0xFF4ADE80),
            ];
            return _EditPeriodTile(
              key: ValueKey('$day-$i'),
              index: i,
              entry: periods[i],
              color: colors[i % colors.length],
              slotTimeHint: hint,
              attendanceSubjects: _attendanceSubjects,
              subjectAliases: _subjectAliases,
              onChanged: (u) => _updatePeriod(day, i, u),
              onRemove: () => _removePeriod(day, i),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => _addPeriod(day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: VergeTheme.canvasBlack,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VergeTheme.jellyMint.withValues(alpha: 0.2)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, color: VergeTheme.jellyMint, size: 18),
                  SizedBox(width: 6),
                  Text('Add Period',
                      style: TextStyle(color: VergeTheme.jellyMint, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ),
          ),
          if (periods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                Icon(Icons.add_circle_outline_rounded, color: VergeTheme.secondaryText, size: 36),
                const SizedBox(height: 10),
                Text('No periods added for $fullDay yet.',
                    style: TextStyle(color: VergeTheme.secondaryText, fontSize: 13)),
              ]),
            ),
        ],
      );
    }

    // View mode: render all 8 fixed slots (slot 4 = lunch)
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _kSlots.length,
      itemBuilder: (_, slotIdx) {
        final slot = _kSlots[slotIdx];
        if (slot.isLunch) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildLunchTile(slotIdx, activeSlot, isToday),
          );
        }
        final periodIdx = slotIdx < 4 ? slotIdx : slotIdx - 1;
        final entry     = periodIdx < periods.length ? periods[periodIdx] : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildViewTile(slotIdx, periodIdx, slot, entry, activeSlot, isToday),
        );
      },
    );
  }

  // ─── View tiles ───────────────────────────────────────────────────────────

  Widget _buildViewTile(int slotIdx, int periodIdx, _PeriodSlot slot,
      PeriodEntry? entry, int activeSlot, bool isToday) {
    final isCurrent = isToday && activeSlot == slotIdx;
    final isDone    = isToday && _slotDone(slotIdx, _now);
    final isEmpty   = entry == null || entry.subjectCode.isEmpty;

    final colors = [
      VergeTheme.jellyMint, const Color(0xFFA78BFA), const Color(0xFF34D399),
      const Color(0xFFFBBF24), const Color(0xFFF87171), const Color(0xFF38BDF8),
      const Color(0xFFE879F9), const Color(0xFF4ADE80),
    ];
    final accent = isEmpty ? VergeTheme.dimGray : colors[periodIdx % colors.length];

    final bool isFree = entry?.isFree ?? false;

    final Color borderCol = isCurrent
        ? VergeTheme.jellyMint.withValues(alpha: 0.6)
        : isDone
            ? VergeTheme.jellyMint.withValues(alpha: 0.25)
            : isFree
                ? VergeTheme.jellyMint.withValues(alpha: 0.1)
                : VergeTheme.hazardWhite.withValues(alpha: 0.06);
    final Color bgCol = isCurrent
        ? VergeTheme.jellyMint.withValues(alpha: 0.07)
        : isDone
            ? VergeTheme.jellyMint.withValues(alpha: 0.04)
            : isFree
                ? VergeTheme.jellyMint.withValues(alpha: 0.02)
                : VergeTheme.canvasBlack;

    final label = isFree ? 'Free Period' : (isEmpty ? '—' : ((entry?.alias.isNotEmpty ?? false) ? entry!.alias : entry!.subjectCode));
    final subText = isFree || isEmpty ? null : ((entry?.alias.isNotEmpty ?? false) ? entry!.subjectCode : entry!.subjectName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
        boxShadow: isCurrent
            ? [BoxShadow(color: VergeTheme.jellyMint.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Badge
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isDone
                  ? VergeTheme.jellyMint.withValues(alpha: 0.12)
                  : isCurrent
                      ? VergeTheme.jellyMint.withValues(alpha: 0.15)
                      : accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDone
                    ? VergeTheme.jellyMint.withValues(alpha: 0.3)
                    : isCurrent
                        ? VergeTheme.jellyMint.withValues(alpha: 0.4)
                        : accent.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded, color: VergeTheme.jellyMint, size: 16)
                  : isCurrent
                      ? const Icon(Icons.play_arrow_rounded, color: VergeTheme.jellyMint, size: 18)
                      : isFree
                          ? Icon(Icons.coffee_rounded, color: VergeTheme.jellyMint.withValues(alpha: 0.5), size: 16)
                          : Text('${periodIdx + 1}',
                              style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 14),
          // Subject info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                        color: isDone
                            ? VergeTheme.jellyMint.withValues(alpha: 0.8)
                            : isFree ? VergeTheme.jellyMint.withValues(alpha: 0.7)
                            : isEmpty ? VergeTheme.secondaryText : VergeTheme.hazardWhite,
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      )),
                ),
                if (entry != null && entry.isPractical) ...[
                  const SizedBox(width: 6), _badge('P', Colors.blueAccent)],
                if (entry != null && entry.isSL) ...[
                  const SizedBox(width: 4), _badge('SL', Colors.purpleAccent)],
              ]),
              const SizedBox(height: 2),
              if (subText != null && subText.isNotEmpty)
                Text(subText,
                    style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis)
              else if (entry != null && entry.subjectName.isNotEmpty && entry.alias.isEmpty)
                Text(entry.subjectName,
                    style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 10),
          // Time + status
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(slot.timeRange,
                style: TextStyle(
                  color: isCurrent ? VergeTheme.jellyMint : VergeTheme.secondaryText,
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                )),
            const SizedBox(height: 4),
            if (isCurrent)       _chip('Now',  VergeTheme.jellyMint)
            else if (isDone)     _chip('Done', VergeTheme.jellyMint)
            else                 _chip(slot.label.replaceAll(' Period', ''), VergeTheme.dimGray.withValues(alpha: 0.5)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildLunchTile(int slotIdx, int activeSlot, bool isToday) {
    final slot      = _kSlots[slotIdx];
    final isCurrent = isToday && activeSlot == slotIdx;
    final isDone    = isToday && _slotDone(slotIdx, _now);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: isCurrent
            ? VergeTheme.jellyMint.withValues(alpha: 0.06)
            : isDone
                ? VergeTheme.jellyMint.withValues(alpha: 0.03)
                : VergeTheme.hazardWhite.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? VergeTheme.jellyMint.withValues(alpha: 0.4)
              : isDone
                  ? VergeTheme.jellyMint.withValues(alpha: 0.2)
                  : VergeTheme.hazardWhite.withValues(alpha: 0.04),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isCurrent
                  ? VergeTheme.jellyMint.withValues(alpha: 0.15)
                  : isDone
                      ? VergeTheme.jellyMint.withValues(alpha: 0.1)
                      : VergeTheme.hazardWhite.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded, color: VergeTheme.jellyMint, size: 16)
                  : Icon(Icons.restaurant_rounded,
                      color: isCurrent ? VergeTheme.jellyMint : VergeTheme.secondaryText, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Lunch Break',
                style: TextStyle(
                  color: isCurrent
                      ? VergeTheme.jellyMint
                      : isDone
                          ? VergeTheme.jellyMint.withValues(alpha: 0.7)
                          : VergeTheme.secondaryText,
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                )),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(slot.timeRange,
                style: TextStyle(
                  color: isCurrent ? VergeTheme.jellyMint : VergeTheme.secondaryText,
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                )),
            const SizedBox(height: 4),
            if (isCurrent)   _chip('Now',   VergeTheme.jellyMint)
            else if (isDone) _chip('Done',  VergeTheme.jellyMint)
            else             _chip('Break', VergeTheme.dimGray.withValues(alpha: 0.5)),
          ]),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Edit tile ────────────────────────────────────────────────────────────────

class _EditPeriodTile extends StatefulWidget {
  final int index;
  final PeriodEntry entry;
  final Color color;
  final String slotTimeHint;
  final List<Map<String, dynamic>> attendanceSubjects;
  final Map<String, String> subjectAliases;
  final ValueChanged<PeriodEntry> onChanged;
  final VoidCallback onRemove;

  const _EditPeriodTile({
    Key? key,
    required this.index,
    required this.entry,
    required this.color,
    required this.slotTimeHint,
    required this.attendanceSubjects,
    required this.subjectAliases,
    required this.onChanged,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<_EditPeriodTile> createState() => _EditPeriodTileState();
}

class _EditPeriodTileState extends State<_EditPeriodTile> {
  late TextEditingController _aliasCtrl;
  String? _selectedKey;
  bool _isSL = false;

  static String _keyFor(Map<String, dynamic> sub) {
    final code = sub['fsubcode']?.toString() ?? '';
    final isPrac = (sub['fsubname'] ?? '').toString().toLowerCase().contains('practical');
    return isPrac ? '${code}_P' : code;
  }

  @override
  void initState() {
    super.initState();
    _aliasCtrl = TextEditingController(text: widget.entry.alias);
    _isSL      = widget.entry.isSL;
    if (widget.entry.isFree) {
      _selectedKey = 'FREE';
    } else if (widget.entry.subjectCode.isNotEmpty) {
      final cand = widget.entry.isPractical
          ? '${widget.entry.subjectCode}_P'
          : widget.entry.subjectCode;
      final exists = widget.attendanceSubjects
          .any((s) => _keyFor(s as Map<String, dynamic>) == cand);
      _selectedKey = exists ? cand : null;
    }
  }

  @override
  void dispose() { _aliasCtrl.dispose(); super.dispose(); }

  void _emit() {
    if (_selectedKey == 'FREE') {
      widget.onChanged(const PeriodEntry(
          subjectCode: '', subjectName: 'Free Period', alias: '', isFree: true));
      return;
    }
    final sub = widget.attendanceSubjects.firstWhere(
      (s) => _keyFor(s as Map<String, dynamic>) == _selectedKey,
      orElse: () => <String, dynamic>{},
    );
    final code   = sub['fsubcode']?.toString() ?? '';
    final name   = sub['fsubname']?.toString()  ?? '';
    final isPrac = name.toLowerCase().contains('practical');
    widget.onChanged(PeriodEntry(
        subjectCode: code, subjectName: name,
        alias: _aliasCtrl.text.trim(), isSL: _isSL, isPractical: isPrac));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VergeTheme.canvasBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('${widget.index + 1}',
                style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13))),
          ),
          const SizedBox(width: 10),
          Text('Period', style: TextStyle(color: VergeTheme.secondaryText, fontSize: 13)),
          const SizedBox(width: 8),
          if (widget.slotTimeHint.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.withValues(alpha: 0.2)),
              ),
              child: Text(widget.slotTimeHint,
                  style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.remove_circle_outline_rounded, color: VergeTheme.ultraviolet, size: 20)),
        ]),
        const SizedBox(height: 12),

        // Subject dropdown
        DropdownButtonFormField<String>(
          value: _selectedKey,
          dropdownColor: VergeTheme.canvasBlack,
          isExpanded: true,
          style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 13),
          hint: Text('Select subject', style: TextStyle(color: VergeTheme.secondaryText, fontSize: 13)),
          decoration: InputDecoration(
            labelText: 'Subject',
            labelStyle: TextStyle(color: VergeTheme.secondaryText, fontSize: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.07)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VergeTheme.jellyMint),
            ),
            filled: true, fillColor: VergeTheme.canvasBlack,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          icon: Icon(Icons.arrow_drop_down, color: VergeTheme.secondaryText),
          items: () {
            final seen = <String>{};
            final List<DropdownMenuItem<String>> items = [];

            // Free Period option
            items.add(const DropdownMenuItem(
              value: 'FREE',
              child: Row(children: [
                Icon(Icons.coffee_rounded, color: VergeTheme.jellyMint, size: 16),
                SizedBox(width: 8),
                Text('Free Period', style: TextStyle(color: VergeTheme.jellyMint, fontSize: 13)),
              ]),
            ));

            items.addAll(widget.attendanceSubjects
                .map((s) => s as Map<String, dynamic>)
                .where((s) => seen.add(_keyFor(s)))
                .map((sub) {
                  final key    = _keyFor(sub);
                  final code   = sub['fsubcode']?.toString() ?? '';
                  final name   = sub['fsubname']?.toString() ?? '';
                  final isPrac = name.toLowerCase().contains('practical');
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Row(children: [
                      Expanded(child: Text('$code – $name',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 13))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPrac
                              ? Colors.blueAccent.withValues(alpha: 0.15)
                              : VergeTheme.dimGray.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(isPrac ? 'P' : 'T',
                            style: TextStyle(
                              color: isPrac ? Colors.blueAccent : VergeTheme.dimGray,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  );
                }).toList());
            return items;
          }(),
          onChanged: (val) {
            setState(() => _selectedKey = val);
            if (val != null) {
              final sub = widget.attendanceSubjects.firstWhere(
                (s) => _keyFor(s as Map<String, dynamic>) == val,
                orElse: () => <String, dynamic>{},
              );
              _aliasCtrl.text = widget.subjectAliases[sub['fsubname']?.toString() ?? ''] ?? '';
            }
            _emit();
          },
        ),
        const SizedBox(height: 10),

        // Alias field
        TextField(
          controller: _aliasCtrl,
          style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 13),
          onChanged: (_) => _emit(),
          decoration: InputDecoration(
            labelText: 'Alias (optional short name)',
            labelStyle: TextStyle(color: VergeTheme.secondaryText, fontSize: 12),
            hintText: 'e.g. Maths, OS, DBMS',
            hintStyle: TextStyle(color: VergeTheme.secondaryText, fontSize: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.07)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VergeTheme.jellyMint),
            ),
            filled: true, fillColor: VergeTheme.canvasBlack,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),

        // SL toggle
        GestureDetector(
          onTap: () { setState(() => _isSL = !_isSL); _emit(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isSL ? Colors.purpleAccent.withValues(alpha: 0.08) : VergeTheme.canvasBlack,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isSL ? Colors.purpleAccent.withValues(alpha: 0.35) : VergeTheme.hazardWhite.withValues(alpha: 0.07)),
            ),
            child: Row(children: [
              Icon(_isSL ? Icons.auto_stories_rounded : Icons.auto_stories_outlined,
                  color: _isSL ? Colors.purpleAccent : VergeTheme.secondaryText, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Self-Learning (SL) Period',
                    style: TextStyle(
                        color: _isSL ? Colors.purpleAccent : VergeTheme.dimGray,
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text('Class may or may not be conducted',
                    style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11)),
              ])),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38, height: 22,
                decoration: BoxDecoration(
                  color: _isSL ? Colors.purpleAccent.withValues(alpha: 0.3) : VergeTheme.dimGray.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _isSL ? Colors.purpleAccent.withValues(alpha: 0.5) : VergeTheme.dimGray.withValues(alpha: 0.2)),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: _isSL ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 16, height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _isSL ? Colors.purpleAccent : VergeTheme.dimGray,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Subject Alias Config Dialog ──────────────────────────────────────────────

class _SubjectAliasConfigDialog extends StatefulWidget {
  final Map<String, String> aliases;
  final List<Map<String, dynamic>> attendanceSubjects;
  final ValueChanged<Map<String, String>> onSave;

  const _SubjectAliasConfigDialog({
    Key? key,
    required this.aliases,
    required this.attendanceSubjects,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_SubjectAliasConfigDialog> createState() => _SubjectAliasConfigDialogState();
}

class _SubjectAliasConfigDialogState extends State<_SubjectAliasConfigDialog> {
  late Map<String, String> _editedAliases;
  late List<Map<String, dynamic>> _uniqueSubjects;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _editedAliases = Map.from(widget.aliases);
    final seen = <String>{};
    _uniqueSubjects = widget.attendanceSubjects.where((sub) {
      final code = sub['fsubcode']?.toString() ?? '';
      final name = sub['fsubname']?.toString() ?? '';
      return seen.add('$code|$name');
    }).toList();
    for (final sub in _uniqueSubjects) {
      final name = sub['fsubname']?.toString() ?? '';
      _controllers.putIfAbsent(name,
          () => TextEditingController(text: _editedAliases[name] ?? ''));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VergeTheme.surfaceSlate,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.08)),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.settings_rounded, color: VergeTheme.jellyMint, size: 20),
            const SizedBox(width: 8),
            const Text('Subject Aliases',
                style: TextStyle(color: VergeTheme.hazardWhite, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, color: VergeTheme.dimGray, size: 20)),
          ]),
          const SizedBox(height: 4),
          Text('Set short names to auto-fill in timetable',
              style: TextStyle(color: VergeTheme.secondaryText, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _uniqueSubjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final sub      = _uniqueSubjects[i];
                final code     = sub['fsubcode']?.toString() ?? '';
                final fullName = sub['fsubname']?.toString() ?? '';
                final ctrl     = _controllers[fullName]!;
                final isPrac   = fullName.toLowerCase().contains('practical');
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VergeTheme.canvasBlack,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(code, style: const TextStyle(
                          color: VergeTheme.jellyMint, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPrac
                              ? Colors.blueAccent.withValues(alpha: 0.12)
                              : VergeTheme.dimGray.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(isPrac ? 'Practical' : 'Theory',
                            style: TextStyle(
                                color: isPrac ? Colors.blueAccent : VergeTheme.secondaryText,
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(fullName, style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl,
                      style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 13),
                      onChanged: (val) => _editedAliases[fullName] = val.trim(),
                      decoration: InputDecoration(
                        hintText: 'e.g. Chemistry, Maths...',
                        hintStyle: TextStyle(color: VergeTheme.secondaryText, fontSize: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.07)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: VergeTheme.jellyMint),
                        ),
                        filled: true, fillColor: VergeTheme.canvasBlack,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _editedAliases.clear();
                  for (final c in _controllers.values) c.clear();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: VergeTheme.ultraviolet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VergeTheme.ultraviolet.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Clear All',
                      style: TextStyle(color: VergeTheme.ultraviolet, fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onSave(_editedAliases),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: VergeTheme.jellyMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VergeTheme.jellyMint.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(color: VergeTheme.jellyMint, fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}