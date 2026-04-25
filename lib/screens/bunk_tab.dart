import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../timetable_service.dart';
import '../widgets/scrolling_text.dart';
import '../theme.dart';

// ─── Pure calculation helpers (no Flutter, easy to unit-test) ────────────────

/// How many consecutive classes must be attended after bunking [bunks] to
/// reach/maintain 85%.  Negative means you still have headroom.
int _mustAttend(int conducted, int attended, int bunks) {
  final newConducted = conducted + bunks;
  return ((0.85 * newConducted - attended) / 0.15).ceil();
}

/// How many more classes can be safely bunked while staying ≥ 85%.
/// Returns 0 if already below 85%.
int _safeToSkip(int conducted, int attended) {
  final headroom = attended - 0.85 * conducted;
  if (headroom <= 0) return 0;
  return (headroom / 0.85).floor();
}

double _pct(int attended, int conducted) =>
    conducted > 0 ? attended / conducted * 100 : 0.0;

// ─── Model ───────────────────────────────────────────────────────────────────

/// Aggregated subject data built from the timetable for selected days.
class _SubjectResult {
  final String displayName;
  final String subjectCode;

  /// Regular (non-SL) theory periods being bunked.
  final int theoryBunks;

  /// Regular (non-SL) practical periods being bunked.
  final int practicalBunks;

  /// SL periods that MAY or MAY NOT be conducted (two scenarios).
  final int slTheoryPeriods;
  final int slPracticalPeriods;

  final Map<String, dynamic>? theoryAtt;   // attendance row for theory
  final Map<String, dynamic>? practicalAtt; // attendance row for practical

  const _SubjectResult({
    required this.displayName,
    required this.subjectCode,
    required this.theoryBunks,
    required this.practicalBunks,
    required this.slTheoryPeriods,
    required this.slPracticalPeriods,
    required this.theoryAtt,
    required this.practicalAtt,
  });

  bool get hasTheory    => theoryBunks > 0    || slTheoryPeriods > 0;
  bool get hasPractical => practicalBunks > 0 || slPracticalPeriods > 0;
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class BunkTab extends StatefulWidget {
  final List<dynamic> attendanceData;
  const BunkTab({Key? key, required this.attendanceData}) : super(key: key);

  @override
  _BunkTabState createState() => _BunkTabState();
}

class _BunkTabState extends State<BunkTab> {
  Map<String, List<PeriodEntry>> _timetable = {};
  bool _loadingTimetable = true;
  String _mode = 'day';

  static const _days     = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const _fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  Set<String> _selectedDays = {};

  // Subject mode
  int? _selectedSubjectIndex;
  final _bunkCtrl = TextEditingController();
  String _bunkResult = '';

  @override
  void initState() {
    super.initState();
    _bunkCtrl.addListener(_calcSubjectBunk);
    _loadTimetable();
    final w = DateTime.now().weekday;
    if (w >= 1 && w <= 5) _selectedDays = {_days[w - 1]};
    if (widget.attendanceData.isNotEmpty) _selectedSubjectIndex = 0;
  }

  @override
  void dispose() {
    _bunkCtrl.removeListener(_calcSubjectBunk);
    _bunkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    final tt = await TimetableService.load();
    if (mounted) setState(() { _timetable = tt; _loadingTimetable = false; });
  }

  // ─── Attendance lookup ───────────────────────────────────────────────────

  /// Finds the attendance row for [code] filtered by theory/practical.
  /// Tries exact code match first, then partial name match.
  Map<String, dynamic>? _findAtt(String code, {required bool practical}) {
    final lc = code.toLowerCase();
    bool matchesPractical(Map<String, dynamic> sub) =>
        (sub['fsubname'] ?? '').toString().toLowerCase().contains('practical');

    // 1. Exact code match WITH type filter
    for (final sub in widget.attendanceData) {
      if ((sub['fsubcode'] ?? '').toString().toLowerCase() == lc) {
        if (matchesPractical(sub) == practical) return sub as Map<String, dynamic>;
      }
    }

    // 2. Exact code match WITHOUT type filter (The "EV" fallback)
    for (final sub in widget.attendanceData) {
      if ((sub['fsubcode'] ?? '').toString().toLowerCase() == lc) {
        return sub as Map<String, dynamic>;
      }
    }

    // 3. Partial match WITH type filter
    for (final sub in widget.attendanceData) {
      final c = (sub['fsubcode'] ?? '').toString().toLowerCase();
      final n = (sub['fsubname'] ?? '').toString().toLowerCase();
      if (n.contains(lc) || lc.contains(c) || c.contains(lc)) {
        if (matchesPractical(sub) == practical) return sub as Map<String, dynamic>;
      }
    }

    // 4. Partial match WITHOUT type filter
    for (final sub in widget.attendanceData) {
      final c = (sub['fsubcode'] ?? '').toString().toLowerCase();
      final n = (sub['fsubname'] ?? '').toString().toLowerCase();
      if (n.contains(lc) || lc.contains(c) || c.contains(lc)) {
        return sub as Map<String, dynamic>;
      }
    }

    return null;
  }

  // ─── Day-mode aggregation ────────────────────────────────────────────────

  List<_SubjectResult> _aggregateSelectedDays() {
    // Accumulator: subjectCode -> mutable counters
    final Map<String, _Accum> acc = {};

    for (final day in _selectedDays) {
      for (final p in (_timetable[day] ?? [])) {
        if (p.subjectCode.isEmpty) continue;
        final key = '${p.subjectCode}::${p.isPractical}';
        acc.putIfAbsent(
          key,
          () => _Accum(
            displayName: p.displayName,
            subjectCode: p.subjectCode,
            isPractical: p.isPractical,
            theoryAtt:    _findAtt(p.subjectCode, practical: false),
            practicalAtt: _findAtt(p.subjectCode, practical: true),
          ),
        );
        if (p.isSL) {
          p.isPractical
              ? acc[key]!.slPractical++
              : acc[key]!.slTheory++;
        } else {
          p.isPractical
              ? acc[key]!.practicalBunks++
              : acc[key]!.theoryBunks++;
        }
      }
    }

    // Merge theory + practical rows for same subject code
    final Map<String, _SubjectResult> merged = {};
    for (final a in acc.values) {
      final existing = merged[a.subjectCode];
      if (existing == null) {
        merged[a.subjectCode] = _SubjectResult(
          displayName:      a.displayName,
          subjectCode:      a.subjectCode,
          theoryBunks:      a.isPractical ? 0 : a.theoryBunks,
          practicalBunks:   a.isPractical ? a.practicalBunks : 0,
          slTheoryPeriods:  a.isPractical ? 0 : a.slTheory,
          slPracticalPeriods: a.isPractical ? a.slPractical : 0,
          theoryAtt:        a.theoryAtt,
          practicalAtt:     a.practicalAtt,
        );
      } else {
        merged[a.subjectCode] = _SubjectResult(
          displayName:        existing.displayName,
          subjectCode:        existing.subjectCode,
          theoryBunks:        existing.theoryBunks    + (a.isPractical ? 0 : a.theoryBunks),
          practicalBunks:     existing.practicalBunks + (a.isPractical ? a.practicalBunks : 0),
          slTheoryPeriods:    existing.slTheoryPeriods    + (a.isPractical ? 0 : a.slTheory),
          slPracticalPeriods: existing.slPracticalPeriods + (a.isPractical ? a.slPractical : 0),
          theoryAtt:          existing.theoryAtt    ?? a.theoryAtt,
          practicalAtt:       existing.practicalAtt ?? a.practicalAtt,
        );
      }
    }

    return merged.values.toList();
  }

  // ─── Subject mode calc ───────────────────────────────────────────────────

  void _calcSubjectBunk() {
    final text = _bunkCtrl.text.trim();
    if (_selectedSubjectIndex == null || text.isEmpty) {
      setState(() => _bunkResult = '');
      return;
    }
    final bunks = int.tryParse(text);
    if (bunks == null || bunks < 0) {
      setState(() => _bunkResult = 'WARN|Enter a valid number.');
      return;
    }
    final sub  = widget.attendanceData[_selectedSubjectIndex!];
    final c    = int.tryParse(sub['conducted'].toString()) ?? 0;
    final a    = int.tryParse(sub['attended'].toString())  ?? 0;
    final must = _mustAttend(c, a, bunks);
    setState(() {
      if (must <= 0) {
        final safe = _safeToSkip(c, a);
        _bunkResult = bunks <= safe
            ? 'SAFE|Safe to bunk $bunks class${bunks == 1 ? '' : 'es'}. You still maintain ≥85%.'
            : 'SAFE|Still above 85% after bunking $bunks class${bunks == 1 ? '' : 'es'}.';
      } else {
        _bunkResult = 'WARN|After bunking $bunks class${bunks == 1 ? '' : 'es'}, '
            'you must attend $must consecutive class${must == 1 ? '' : 'es'} to reach 85%.';
      }
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildModeToggle(),
        const SizedBox(height: 16),
        if (_mode == 'day')     _buildDayMode(),
        if (_mode == 'subject') _buildSubjectMode(),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: VergeTheme.canvasBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(children: [
        _modeBtn('day',     Icons.calendar_today_rounded, 'By Day'),
        _modeBtn('subject', Icons.book_outlined,          'By Subject'),
      ]),
    );
  }

  Widget _modeBtn(String mode, IconData icon, String label) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _mode = mode; _bunkResult = ''; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? VergeTheme.jellyMint.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: VergeTheme.jellyMint.withValues(alpha: 0.4))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: active ? VergeTheme.jellyMint : VergeTheme.secondaryText, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: active ? VergeTheme.jellyMint : VergeTheme.secondaryText,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
          ]),
        ),
      ),
    );
  }

  // ─── DAY MODE ─────────────────────────────────────────────────────────────

  Widget _buildDayMode() {
    final hasTimetable = _timetable.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: VergeTheme.canvasBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VergeTheme.jellyMint.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.calendar_today_rounded, color: VergeTheme.jellyMint, size: 16),
            SizedBox(width: 8),
            Text('Day Bunk Calculator',
                style: TextStyle(color: VergeTheme.jellyMint, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          if (_loadingTimetable)
            const Center(child: CircularProgressIndicator(color: VergeTheme.jellyMint, strokeWidth: 2))
          else if (!hasTimetable)
            _noTimetableWarning()
          else
            _buildDayCheckboxes(),
        ]),
      ),
      if (!_loadingTimetable && hasTimetable && _selectedDays.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildDayResults(),
      ],
    ]);
  }

  Widget _noTimetableWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VergeTheme.jellyMint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VergeTheme.jellyMint.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        const Icon(Icons.calendar_month_outlined, color: VergeTheme.jellyMint, size: 28),
        const SizedBox(height: 8),
        Text('No timetable set up yet.',
            style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.jellyMint)),
        SizedBox(height: 4),
        Text('Go to the Timetable tab to add your weekly schedule.',
            style: TextStyle(color: VergeTheme.jellyMint, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildDayCheckboxes() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Select days to bunk', style: TextStyle(color: VergeTheme.secondaryText, fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: List.generate(_days.length, (i) {
          final day = _days[i];
          final selected = _selectedDays.contains(day);
          final hasPeriods = (_timetable[day] ?? []).isNotEmpty;
          return GestureDetector(
            onTap: () => setState(() {
              selected ? _selectedDays.remove(day) : _selectedDays.add(day);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? VergeTheme.jellyMint : VergeTheme.canvasBlack,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? VergeTheme.jellyMint : VergeTheme.hazardWhite.withValues(alpha: 0.08),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: 5),
                    child: Icon(Icons.check_rounded, size: 13, color: Colors.black),
                  ),
                Text(day, style: TextStyle(
                  color: selected ? Colors.black : VergeTheme.dimGray,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                )),
                if (hasPeriods && !selected) ...[
                  const SizedBox(width: 4),
                  Container(width: 5, height: 5,
                    decoration: const BoxDecoration(color: VergeTheme.jellyMint, shape: BoxShape.circle)),
                ],
              ]),
            ),
          );
        }),
      ),
    ]);
  }

  Widget _buildDayResults() {
    final subjects = _aggregateSelectedDays();
    final dayLabel = _selectedDays.length == 1
        ? _fullDays[_days.indexOf(_selectedDays.first)]
        : '${_selectedDays.length} days';

    if (subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VergeTheme.canvasBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)),
        ),
        child: Center(child: Column(children: [
          Icon(Icons.event_busy_rounded, color: VergeTheme.secondaryText, size: 32),
          const SizedBox(height: 8),
          Text('No periods on selected days', style: TextStyle(color: VergeTheme.secondaryText)),
        ])),
      );
    }

    // Summary counts — count per subject section (theory + practical separately)
    int totalSafe = 0, totalRisk = 0;
    for (final s in subjects) {
      void check(Map<String, dynamic>? att, int bunks) {
        if (att == null || bunks == 0) return;
        final c = int.tryParse(att['conducted'].toString()) ?? 0;
        final a = int.tryParse(att['attended'].toString())  ?? 0;
        _mustAttend(c, a, bunks) <= 0 ? totalSafe++ : totalRisk++;
      }
      check(s.theoryAtt, s.theoryBunks);
      check(s.practicalAtt, s.practicalBunks);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: totalRisk > 0 ? VergeTheme.ultraviolet.withValues(alpha: 0.05) : VergeTheme.canvasBlack,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: totalRisk > 0 ? VergeTheme.ultraviolet.withValues(alpha: 0.2) : VergeTheme.hazardWhite.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Icon(totalRisk > 0 ? Icons.warning_amber_rounded : Icons.summarize_rounded, color: totalRisk > 0 ? VergeTheme.ultraviolet : VergeTheme.jellyMint, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Bunking $dayLabel',
              style: const TextStyle(color: VergeTheme.hazardWhite, fontWeight: FontWeight.w600, fontSize: 13))),
          if (totalSafe > 0) _pill('$totalSafe safe', VergeTheme.jellyMint),
          if (totalRisk > 0) ...[
            const SizedBox(width: 6),
            _pill('$totalRisk at risk', VergeTheme.ultraviolet),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      ...subjects.map((s) => _buildSubjectCard(s)),
    ]);
  }

  Widget _buildSubjectCard(_SubjectResult s) {
    final hasAnyAttendance = s.theoryAtt != null || s.practicalAtt != null;

    if (!hasAnyAttendance) {
      // Unmatched subject — show info card
      final total = s.theoryBunks + s.practicalBunks + s.slTheoryPeriods + s.slPracticalPeriods;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VergeTheme.canvasBlack,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: VergeTheme.dimGray.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.help_outline_rounded, color: VergeTheme.dimGray, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.displayName, style: const TextStyle(color: VergeTheme.hazardWhite, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text('$total period${total == 1 ? '' : 's'} · No matching attendance entry',
                style: TextStyle(color: VergeTheme.secondaryText, fontSize: 12)),
          ])),
        ]),
      );
    }

    return Column(children: [
      if (s.theoryAtt != null && s.hasTheory)
        _buildVariantCard(s, practical: false),
      if (s.practicalAtt != null && s.hasPractical) ...[
        if (s.theoryAtt != null && s.hasTheory) const SizedBox(height: 10),
        _buildVariantCard(s, practical: true),
      ],
    ]);
  }

  /// Builds a single theory or practical attendance impact card.
  ///
  /// SL LOGIC (correct):
  ///   - SL = Self-Learning period. The class MAY or MAY NOT be conducted.
  ///   - Regular bunk: student skips → class IS conducted → attendance drops.
  ///   - SL period has two scenarios:
  ///       Scenario A: SL not conducted → no impact on conducted count at all.
  ///       Scenario B: SL conducted (student absent) → conducted++ but attended stays same.
  ///   - The main card shows impact of regular bunks only.
  ///   - The SL section shows the two conditional scenarios separately.
  Widget _buildVariantCard(_SubjectResult s, {required bool practical}) {
    final att       = practical ? s.practicalAtt! : s.theoryAtt!;
    final bunks     = practical ? s.practicalBunks     : s.theoryBunks;
    final slPeriods = practical ? s.slPracticalPeriods : s.slTheoryPeriods;

    final c = int.tryParse(att['conducted'].toString()) ?? 0;
    final a = int.tryParse(att['attended'].toString())  ?? 0;

    final currentPct = _pct(a, c);

    // After bunking regular (non-SL) classes
    final afterBunkConducted = c + bunks;
    final afterBunkPct = _pct(a, afterBunkConducted);
    final must    = _mustAttend(c, a, bunks);
    final isSafe  = must <= 0;
    final safeRem = isSafe ? _safeToSkip(c + bunks, a) : 0;

    final mainColor = isSafe ? VergeTheme.jellyMint : VergeTheme.ultraviolet;

    // SL Scenario A: SL periods NOT conducted → same as afterBunk state
    final slA_pct  = afterBunkPct;   // no change to conducted
    final slA_must = must;           // same requirement
    final slA_safe = safeRem;

    // SL Scenario B: SL periods conducted, student absent → conducted += slPeriods
    final slB_conducted = afterBunkConducted + slPeriods;
    final slB_pct  = _pct(a, slB_conducted);
    final slB_must = _mustAttend(c, a, bunks + slPeriods); // full impact
    final slB_safe = slB_must <= 0 ? _safeToSkip(slB_conducted, a) : 0;
    final slB_safe_color = slB_must <= 0 ? VergeTheme.jellyMint : VergeTheme.ultraviolet;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSafe ? VergeTheme.canvasBlack : VergeTheme.ultraviolet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mainColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(s.displayName,
                    style: const TextStyle(color: VergeTheme.hazardWhite, fontWeight: FontWeight.w600, fontSize: 14))),
                const SizedBox(width: 6),
                _badge(practical ? 'P' : 'T',
                    practical ? VergeTheme.jellyMint : VergeTheme.dimGray),
                if (slPeriods > 0) ...[
                  const SizedBox(width: 4),
                  _badge('$slPeriods SL', VergeTheme.jellyMint),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                bunks == 0
                    ? 'No regular periods bunked${slPeriods > 0 ? ' · $slPeriods SL period${slPeriods > 1 ? 's' : ''}' : ''}'
                    : '$bunks period${bunks == 1 ? '' : 's'} bunked'
                      '${slPeriods > 0 ? ' · $slPeriods SL' : ''}',
                style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11),
              ),
            ])),
            if (bunks > 0)
              Icon(isSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: mainColor, size: 20),
          ]),

          // ── Regular bunk impact (only show if there are actual bunks) ──
          if (bunks > 0) ...[
            const SizedBox(height: 12),
            Row(children: [
              _miniStat('Before', '${currentPct.toStringAsFixed(1)}%', _pctColor(currentPct)),
              _divider(),
              _miniStat('After',  '${afterBunkPct.toStringAsFixed(1)}%', _pctColor(afterBunkPct)),
              _divider(),
              _miniStat('Attended', '$a/$afterBunkConducted', VergeTheme.hazardWhite),
            ]),
            const SizedBox(height: 10),
            _progressBar(currentPct, afterBunkPct, context),
            const SizedBox(height: 10),
            _statusBox(
              isSafe
                  ? 'Still ≥85% after bunking. ${safeRem > 0 ? 'Can afford $safeRem more.' : 'No more headroom.'}'
                  : 'Must attend $must more class${must == 1 ? '' : 'es'} to reach 85%.',
              mainColor,
            ),
          ],

          // ── SL section ──────────────────────────────────────────────────
          if (slPeriods > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VergeTheme.jellyMint.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VergeTheme.jellyMint.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.auto_stories_rounded, color: VergeTheme.jellyMint, size: 14),
                  const SizedBox(width: 6),
                  Text('SL Period Scenarios',
                      style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.jellyMint)),
                ]),
                const SizedBox(height: 4),
                Text('$slPeriods self-learning period${slPeriods > 1 ? 's' : ''} — impact depends on whether class is held:',
                    style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11)),
                const SizedBox(height: 10),

                // Scenario A: SL not conducted (student absent, class cancelled)
                _slRow(
                  icon: Icons.event_busy_rounded,
                  label: 'SL not conducted',
                  sublabel: 'Class cancelled — no impact on attendance',
                  pct: slA_pct,
                  isSafe: slA_must <= 0,
                  detail: slA_must <= 0
                      ? (slA_safe > 0 ? 'Can still afford $slA_safe more' : 'At 85% limit')
                      : 'Need $slA_must more',
                ),
                const SizedBox(height: 8),

                // Scenario B: SL conducted, student absent
                _slRow(
                  icon: Icons.school_rounded,
                  label: 'SL conducted (you absent)',
                  sublabel: 'Counted in conducted — attendance drops further',
                  pct: slB_pct,
                  isSafe: slB_must <= 0,
                  detail: slB_must <= 0
                      ? (slB_safe > 0 ? 'Can still afford $slB_safe more' : 'At 85% limit')
                      : 'Need $slB_must more',
                  pctColor: slB_safe_color,
                ),
              ]),
            ),
          ],

          // ── If no regular bunks but has SL only, show base state ────────
          if (bunks == 0 && slPeriods == 0) ...[
            const SizedBox(height: 8),
            Text('No periods to analyse for this day.',
                style: TextStyle(color: VergeTheme.secondaryText, fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  // ─── Small UI helpers ─────────────────────────────────────────────────────

  Widget _slRow({
    required IconData icon,
    required String label,
    required String sublabel,
    required double pct,
    required bool isSafe,
    required String detail,
    Color? pctColor,
  }) {
    final col = pctColor ?? (isSafe ? VergeTheme.jellyMint : VergeTheme.ultraviolet);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: col, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: VergeTheme.hazardWhite.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
        Text(sublabel, style: TextStyle(color: VergeTheme.secondaryText, fontSize: 10)),
      ])),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${pct.toStringAsFixed(1)}%',
            style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: col.withValues(alpha: 0.2)),
          ),
          child: Text(detail, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    ]);
  }

  Widget _progressBar(double before, double after, BuildContext ctx) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (before / 100).clamp(0.0, 1.0),
          backgroundColor: VergeTheme.hazardWhite.withValues(alpha: 0.05),
          valueColor: AlwaysStoppedAnimation<Color>(_pctColor(before).withValues(alpha: 0.25)),
          minHeight: 6,
        ),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (after / 100).clamp(0.0, 1.0),
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(_pctColor(after)),
          minHeight: 6,
        ),
      ),
      // 85% marker line
      Positioned(
        left: MediaQuery.of(ctx).size.width * 0.85 - 52,
        top: 0, bottom: 0,
        child: Container(width: 1.5, color: VergeTheme.hazardWhite.withValues(alpha: 0.3)),
      ),
    ]);
  }

  Widget _statusBox(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
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

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 32,
    color: VergeTheme.hazardWhite.withValues(alpha: 0.06),
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );

  Color _pctColor(double pct) {
    if (pct < 75) return VergeTheme.ultraviolet;
    if (pct < 85) return VergeTheme.ultraviolet;
    return VergeTheme.jellyMint;
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }

  // ─── SUBJECT MODE ─────────────────────────────────────────────────────────

  Widget _buildSubjectMode() {
    if (widget.attendanceData.isEmpty) {
      return const Center(child: Text('No attendance data.', style: TextStyle(color: VergeTheme.dimGray)));
    }

    return Container(
      decoration: BoxDecoration(
        color: VergeTheme.canvasBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VergeTheme.jellyMint.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.book_outlined, color: VergeTheme.jellyMint, size: 16),
          SizedBox(width: 8),
          Text('Subject Bunk Calculator',
              style: TextStyle(color: VergeTheme.jellyMint, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 14),

        DropdownButtonFormField<int>(
          value: _selectedSubjectIndex,
          dropdownColor: VergeTheme.canvasBlack,
          isExpanded: true,
          style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Select Subject',
            labelStyle: TextStyle(color: VergeTheme.secondaryText, fontSize: 13),
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
          selectedItemBuilder: (context) => List.generate(widget.attendanceData.length, (i) {
            final item = widget.attendanceData[i];
            return ScrollingText(
              text: '${item['fsubcode']} – ${item['fsubname']}',
              style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 13),
            );
          }),
          items: List.generate(widget.attendanceData.length, (i) {
            final item = widget.attendanceData[i];
            return DropdownMenuItem<int>(
              value: i,
              child: Text('${item['fsubcode']} – ${item['fsubname']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 13)),
            );
          }),
          onChanged: (val) => setState(() {
            _selectedSubjectIndex = val;
            _bunkResult = '';
            _bunkCtrl.clear();
          }),
        ),
        const SizedBox(height: 12),
        if (_selectedSubjectIndex != null) _buildSubjectStats(),
        const SizedBox(height: 12),

        TextField(
          controller: _bunkCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: VergeTheme.hazardWhite),
          decoration: InputDecoration(
            labelText: 'Number of classes to bunk',
            labelStyle: TextStyle(color: VergeTheme.secondaryText, fontSize: 13),
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
        if (_bunkResult.isNotEmpty) ...[
          const SizedBox(height: 12),
          _resultBox(_bunkResult),
        ],
      ]),
    );
  }

  Widget _buildSubjectStats() {
    final sub = widget.attendanceData[_selectedSubjectIndex!];
    final c   = int.tryParse(sub['conducted'].toString()) ?? 0;
    final a   = int.tryParse(sub['attended'].toString())  ?? 0;
    final pct = _pct(a, c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: VergeTheme.canvasBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.05)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _miniStat('Conducted', '$c', VergeTheme.hazardWhite),
        _miniStat('Attended',  '$a', VergeTheme.hazardWhite),
        _miniStat('Current', '${pct.toStringAsFixed(1)}%', _pctColor(pct)),
      ]),
    );
  }

  Widget _resultBox(String result) {
    final bool isSafe = result.startsWith('SAFE|');
    final String text = result.length > 5 ? result.substring(5) : result;
    final Color color = isSafe ? VergeTheme.jellyMint : VergeTheme.ultraviolet;
    final IconData icon = isSafe ? Icons.check_circle_rounded : Icons.warning_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ─── Internal accumulator ────────────────────────────────────────────────────

class _Accum {
  final String displayName;
  final String subjectCode;
  final bool isPractical;
  int theoryBunks    = 0;
  int practicalBunks = 0;
  int slTheory       = 0;
  int slPractical    = 0;
  final Map<String, dynamic>? theoryAtt;
  final Map<String, dynamic>? practicalAtt;

  _Accum({
    required this.displayName,
    required this.subjectCode,
    required this.isPractical,
    required this.theoryAtt,
    required this.practicalAtt,
  });
}
