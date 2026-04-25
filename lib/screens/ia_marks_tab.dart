import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class IaMarksTab extends StatefulWidget {
  final Map<String, dynamic> iaMarksData;
  final RefreshCallback onRefresh;

  const IaMarksTab({Key? key, required this.iaMarksData, required this.onRefresh}) : super(key: key);

  @override
  State<IaMarksTab> createState() => _IaMarksTabState();
}

class _IaMarksTabState extends State<IaMarksTab> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool('ia_setup_done') ?? false;
    if (!setupDone) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () => _showSetupGuide());
      }
    }
  }

  void _showSetupGuide() {
    final rows = widget.iaMarksData['rows'] ?? [];
    final headers = widget.iaMarksData['headers'] ?? [];
    
    final hUpper = headers.map((h) => h.toString().toUpperCase()).toList();
    final nameIdx = hUpper.indexWhere((h) => h.contains('SUB. NAME') || h.contains('SUBJECT NAME'));
    final codeIdx = hUpper.indexWhere((h) => h.contains('SUB. CODE') || h.contains('SUBJECT CODE'));

    final subjects = <Map<String, String>>[];
    final seenCodes = <String>{};

    for (var row in rows) {
      final r = row as List<dynamic>;
      final name = nameIdx != -1 ? r[nameIdx].toString() : r[0].toString();
      final code = codeIdx != -1 ? r[codeIdx].toString() : '';
      final key = code.isNotEmpty ? code : name;
      
      if (!seenCodes.contains(key)) {
        subjects.add({'name': name, 'code': key});
        seenCodes.add(key);
      }
    }

    final selectedCbt = <String, bool>{};
    for (var s in subjects) selectedCbt[s['code']!] = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: VergeTheme.canvasBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: VergeTheme.jellyMint.withValues(alpha: 0.5)),
            ),
            title: Text('SELECT CBT SUBJECTS', style: VergeTheme.headingSmall.copyWith(color: VergeTheme.hazardWhite)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Check the subjects that follow CBT mode (Mid-Sem marks out of 20). Others will follow Normal mode (out of 15).',
                      style: TextStyle(color: VergeTheme.secondaryText, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ...subjects.map((s) {
                      final isSel = selectedCbt[s['code']] ?? false;
                      return CheckboxListTile(
                        title: Text(s['name']!.toUpperCase(), style: VergeTheme.monoTimestamp.copyWith(color: VergeTheme.hazardWhite, fontSize: 10)),
                        subtitle: Text(s['code']!, style: TextStyle(color: VergeTheme.secondaryText, fontSize: 10)),
                        value: isSel,
                        activeColor: VergeTheme.jellyMint,
                        checkColor: VergeTheme.absoluteBlack,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => selectedCbt[s['code']!] = val ?? false),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  for (var entry in selectedCbt.entries) {
                    await prefs.setBool('cbt_ia_${entry.key}', entry.value);
                  }
                  await prefs.setBool('ia_setup_done', true);
                  if (context.mounted) {
                    Navigator.pop(context);
                    widget.onRefresh();
                  }
                },
                child: Text('SAVE PREFERENCES', style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.jellyMint)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> rawHeaders = widget.iaMarksData['headers'] ?? [];
    final List<dynamic> rows = widget.iaMarksData['rows'] ?? [];

    if (rawHeaders.isEmpty && rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grade_outlined, color: VergeTheme.secondaryText, size: 40),
            const SizedBox(height: 12),
            Text('NO IA MARKS DATA FOUND.', style: VergeTheme.monoTimestamp),
            const SizedBox(height: 6),
            Text('PULL DOWN TO REFRESH', style: VergeTheme.monoTimestamp),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: VergeTheme.absoluteBlack,
      backgroundColor: VergeTheme.jellyMint,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final rowData = rows[index] as List<dynamic>;
          return _IaSubjectCard(
            rowData: rowData,
            headers: rawHeaders,
          );
        },
      ),
    );
  }
}

class _IaSubjectCard extends StatefulWidget {
  final List<dynamic> rowData;
  final List<dynamic> headers;

  const _IaSubjectCard({Key? key, required this.rowData, required this.headers}) : super(key: key);

  @override
  State<_IaSubjectCard> createState() => _IaSubjectCardState();
}

class _IaSubjectCardState extends State<_IaSubjectCard> {
  bool _expanded = false;
  bool _isCbt = false;
  String _subjectCode = '';

  @override
  void initState() {
    super.initState();
    _loadCbtPreference();
  }

  Future<void> _loadCbtPreference() async {
    final hUpper = widget.headers.map((h) => h.toString().toUpperCase()).toList();
    final codeIdx = hUpper.indexWhere((h) => h.contains('SUB. CODE') || h.contains('SUBJECT CODE'));
    final rawName = widget.rowData[0].toString();
    _subjectCode = codeIdx != -1 ? widget.rowData[codeIdx].toString() : _extractCode(rawName);
    
    if (_subjectCode.isEmpty) _subjectCode = rawName;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCbt = prefs.getBool('cbt_ia_$_subjectCode') ?? false;
    });
  }

  Future<void> _toggleCbt() async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = !_isCbt;
    await prefs.setBool('cbt_ia_$_subjectCode', newVal);
    setState(() => _isCbt = newVal);
  }

  String _cleanSubjectName(String name) {
    final parts = name.split('-');
    final cleanParts = parts.where((p) {
      final t = p.trim();
      if (!t.contains(' ') && RegExp(r'\d').hasMatch(t) && RegExp(r'[A-Za-z]').hasMatch(t) && t.length >= 5 && t.length <= 10) {
        return false;
      }
      return true;
    });
    return cleanParts.join(' - ').trim();
  }

  String _extractCode(String name) {
    final parts = name.split('-');
    for (final p in parts) {
      final t = p.trim();
      if (!t.contains(' ') && RegExp(r'\d').hasMatch(t) && RegExp(r'[A-Za-z]').hasMatch(t) && t.length >= 5 && t.length <= 10) {
        return t;
      }
    }
    return '';
  }

  Color _getScoreColor(String header, String value, bool isCbt) {
    final num? val = num.tryParse(value);
    if (val == null) return VergeTheme.secondaryText;

    final h = header.toUpperCase();
    
    if (h.contains('IA') || 
        h.contains('INTERNAL') || 
        h == 'RECORD' || 
        h == 'CONDUCTANCE') {
      return VergeTheme.hazardWhite;
    }

    if (h.contains('LAB MSE') || h.contains('PRACTICAL MSE')) {
      if (val < 15) return VergeTheme.ultraviolet;
      if (val >= 24) return VergeTheme.jellyMint;
      return VergeTheme.hazardWhite;
    }

    if (h.contains('MSE') || h.contains('MID SEM') || h.contains('TEST')) {
      final max = isCbt ? 20 : 15;
      if (val < (max * 0.5)) return VergeTheme.ultraviolet;
      if (val >= (max * 0.8)) return VergeTheme.jellyMint;
      return VergeTheme.hazardWhite;
    }

    return VergeTheme.hazardWhite;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rowData.isEmpty) return const SizedBox();

    final hUpper = widget.headers.map((h) => h.toString().toUpperCase()).toList();
    final nameIdx = hUpper.indexWhere((h) => h.contains('SUB. NAME') || h.contains('SUBJECT NAME'));
    final codeIdx = hUpper.indexWhere((h) => h.contains('SUB. CODE') || h.contains('SUBJECT CODE'));

    final subjectName = nameIdx != -1 ? widget.rowData[nameIdx].toString() : widget.rowData[0].toString();
    final subjectCode = codeIdx != -1 ? widget.rowData[codeIdx].toString() : '';

    final cleanName = _cleanSubjectName(subjectName);
    final code = subjectCode.isNotEmpty ? subjectCode : _extractCode(subjectName);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onLongPress: _toggleCbt,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _expanded ? VergeTheme.surfaceSlate.withValues(alpha: 0.5) : VergeTheme.canvasBlack,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _expanded ? VergeTheme.jellyMint : VergeTheme.hazardWhite, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (code.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      code.toUpperCase(),
                      style: VergeTheme.eyebrowAllCaps.copyWith(color: VergeTheme.jellyMint),
                    ),
                    if (_isCbt)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: VergeTheme.jellyMint.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: VergeTheme.jellyMint,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'CBT',
                          style: VergeTheme.monoTimestamp.copyWith(
                            color: VergeTheme.jellyMint,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cleanName.toUpperCase(),
                      style: VergeTheme.headingSmall.copyWith(color: VergeTheme.hazardWhite),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: _expanded ? VergeTheme.jellyMint : VergeTheme.secondaryText,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded ? _buildStatsGrid() : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(width: double.infinity, height: 1, color: VergeTheme.hazardWhite.withValues(alpha: 0.1)),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final col1 = <int>[];
            final col2 = <int>[];
            for (int i = 0; i < widget.rowData.length; i++) {
              final h = widget.headers[i].toString().toUpperCase();
              if (h.isEmpty ||
                  h.contains('SL. NO.') ||
                  h.contains('SEM') ||
                  h.contains('SUB. CODE') ||
                  h.contains('SUBJECT CODE') ||
                  h.contains('SUB. NAME') ||
                  h.contains('SUBJECT NAME')) {
                continue;
              }

              if (h.contains('LA1') || h.contains('LA2') || h.contains('LA3') || h.contains('LA4') ||
                  h.contains('LA 1') || h.contains('LA 2') || h.contains('LA 3') || h.contains('LA 4')) {
                col2.add(i);
              } else {
                col1.add(i);
              }
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: col1.map((i) => _buildStatItem(i)).toList(),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: col2.map((i) => _buildStatItem(i)).toList(),
                  ),
                ),
              ],
            );
          }
        ),
      ],
    );
  }

  Widget _buildStatItem(int colIdx) {
    final header = widget.headers[colIdx].toString();
    final rawVal = widget.rowData[colIdx].toString().trim();
    final hasValue = rawVal.isNotEmpty && rawVal != '-';
    final displayVal = hasValue ? rawVal : 'No entry yet';
    final color = hasValue ? _getScoreColor(header, rawVal, _isCbt) : VergeTheme.secondaryText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header.toUpperCase(),
            style: VergeTheme.monoTimestamp.copyWith(color: VergeTheme.secondaryText, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            displayVal,
            style: hasValue
                ? VergeTheme.largeHeadline.copyWith(color: color, fontSize: 22)
                : TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
