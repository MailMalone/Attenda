import 'dart:ui';
import 'package:flutter/material.dart';
import '../subject_alias_service.dart';
import '../cloud_storage_service.dart';
import '../local_storage_service.dart';
import '../theme.dart';
import 'package:open_filex/open_filex.dart';
import 'package:animations/animations.dart';

class StudyTab extends StatefulWidget {
  final List<dynamic> attendanceData;
  const StudyTab({Key? key, required this.attendanceData}) : super(key: key);

  @override
  _StudyTabState createState() => _StudyTabState();
}

class _StudyTabState extends State<StudyTab> {
  // Map structure: { subjectCode: { 'alias': '...', 'fullName': '...', 'pdfs': [...] } }
  Map<String, Map<String, dynamic>> _availableSubjects = {};
  List<String> _checkedCodes = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void didUpdateWidget(StudyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attendanceData != widget.attendanceData) {
      _checkAvailability();
    }
  }

  String _extractRealCode(String subCode, String subName) {
    final fullString = '$subCode - $subName';
    final parts = fullString.split(RegExp(r'[-—]'));
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i].trim();
      if (part.isNotEmpty && part.length >= 4 && part.length <= 12) {
        if (RegExp(r'\d').hasMatch(part) && RegExp(r'[A-Za-z]').hasMatch(part)) {
          return part;
        }
      }
    }
    return subCode.trim();
  }

  Future<void> _checkAvailability() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final aliases = await SubjectAliasService.load();
    final manifest = await CloudStorageService.fetchNotesManifest();
    
    final available = <String, Map<String, dynamic>>{};
    final checked = <String>[];

    for (final sub in widget.attendanceData) {
      if (sub is! Map<String, dynamic>) continue;
      
      final rawCode = sub['fsubcode']?.toString() ?? '';
      final fullName = sub['fsubname']?.toString() ?? '';
      final code = _extractRealCode(rawCode, fullName);
      
      if (code.isEmpty) continue;
      if (available.containsKey(code)) continue;
      checked.add(code);

      final pdfs = CloudStorageService.getPdfsForSubjectFromManifest(manifest, code);
      if (pdfs.isNotEmpty) {
        final alias = aliases[fullName] ?? '';
        available[code] = {
          'fullName': fullName,
          'alias': alias.isNotEmpty ? alias : fullName,
          'pdfs': pdfs,
        };
      }
    }

    if (mounted) {
      setState(() {
        _availableSubjects = available;
        _checkedCodes = checked;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => _isRefreshing = true);
              await _checkAvailability();
              setState(() => _isRefreshing = false);
            },
            color: VergeTheme.jellyMint,
            backgroundColor: VergeTheme.canvasBlack,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)))),
      child: Row(children: [
        const Icon(Icons.library_books_rounded, color: VergeTheme.jellyMint, size: 16),
        const SizedBox(width: 8),
        const Text('Study Material',
            style: TextStyle(color: VergeTheme.jellyMint, fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        _headerBtn(
          icon: Icons.refresh_rounded, 
          label: 'Sync',
          color: VergeTheme.jellyMint, 
          onTap: _checkAvailability
        ),
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

  Widget _buildBody() {
    // Show central spinner ONLY on first load (when list is empty) and NOT during pull-to-refresh
    if (_isLoading && _availableSubjects.isEmpty && !_isRefreshing) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const Center(child: CircularProgressIndicator(color: VergeTheme.jellyMint)),
          const SizedBox(height: 16),
          const Center(
            child: Text('Loading notes manifest...', 
                style: TextStyle(color: VergeTheme.dimGray, fontSize: 13)),
          ),
        ],
      );
    }

    if (widget.attendanceData.isEmpty) {
      return _scrollableEmptyState(Icons.menu_book_rounded, 'No subjects found', 'No attendance data detected. Pull down to refresh on the Attendance tab.');
    }

    if (_availableSubjects.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32.0),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.cloud_off_rounded, size: 64, color: VergeTheme.dimGray),
          const SizedBox(height: 16),
          Center(child: Text('No notes found', style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.hazardWhite))),
          const SizedBox(height: 12),
          Text(
            'Make sure you have created the "notes_index.json" file in your GitHub "Notes" folder.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VergeTheme.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _debugBox(),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              onPressed: _checkAvailability,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Check'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VergeTheme.jellyMint,
                foregroundColor: VergeTheme.canvasBlack,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _availableSubjects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final subjectCode = _availableSubjects.keys.elementAt(index);
        final data = _availableSubjects[subjectCode]!;
        final displayTitle = data['alias']!;
        final pdfs = data['pdfs'] as List<Map<String, String>>;

        return OpenContainer(
          closedElevation: 0,
          closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          closedColor: VergeTheme.canvasBlack,
          openColor: VergeTheme.canvasBlack,
          middleColor: VergeTheme.canvasBlack,
          transitionType: ContainerTransitionType.fade,
          transitionDuration: const Duration(milliseconds: 350),
          openBuilder: (context, action) => PdfListScreen(subjectCode: subjectCode, subjectAlias: displayTitle, initialPdfs: pdfs),
          closedBuilder: (context, action) => InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VergeTheme.canvasBlack,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VergeTheme.jellyMint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_outlined, color: VergeTheme.jellyMint),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(displayTitle, style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.hazardWhite)),
                      const SizedBox(height: 4),
                      Text('$subjectCode • ${pdfs.length} files', style: TextStyle(color: VergeTheme.secondaryText, fontSize: 12)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: VergeTheme.secondaryText),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scrollableEmptyState(IconData icon, String title, String desc) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 64, color: VergeTheme.dimGray),
              const SizedBox(height: 16),
              Text(title, style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.hazardWhite)),
              const SizedBox(height: 8),
              Text(desc, textAlign: TextAlign.center, style: TextStyle(color: VergeTheme.secondaryText, fontSize: 14)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _debugBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VergeTheme.canvasBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Text('Codes scanned from your subjects:', style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.hazardWhite)),
        const SizedBox(height: 8),
        Text(_checkedCodes.isEmpty ? 'None' : _checkedCodes.join(', '),
            style: TextStyle(color: VergeTheme.secondaryText, fontSize: 11), textAlign: TextAlign.center),
      ]),
    );
  }


}

class PdfListScreen extends StatefulWidget {
  final String subjectCode;
  final String subjectAlias;
  final List<Map<String, String>> initialPdfs;

  const PdfListScreen({Key? key, required this.subjectCode, required this.subjectAlias, required this.initialPdfs}) : super(key: key);

  @override
  _PdfListScreenState createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  late List<Map<String, String>> _pdfs;
  final Map<String, bool> _downloadedStatus = {};
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    _pdfs = widget.initialPdfs;
    _checkDownloadStatuses();
  }

  Future<void> _checkDownloadStatuses() async {
    final Map<String, bool> newStatuses = {};
    for (final pdf in _pdfs) {
      final name = pdf['name'] ?? '';
      if (name.isEmpty) continue;
      newStatuses[name] = await LocalStorageService.isNoteDownloaded(widget.subjectAlias, name);
    }
    if (mounted) {
      setState(() => _downloadedStatus.addAll(newStatuses));
    }
  }

  Future<void> _onPdfTap(Map<String, String> pdf) async {
    final name = pdf['name'] ?? 'Document';
    final url = pdf['url'] ?? '';

    // ── If already downloaded, open it directly (no permission check needed) ──
    final localPath = await LocalStorageService.getLocalNotePath(widget.subjectAlias, name);
    if (localPath != null) {
      final result = await OpenFilex.open(localPath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result.message}'), backgroundColor: VergeTheme.canvasBlack),
        );
      }
      return;
    }

    if (url.isEmpty) return;

    // ── Step 1: ensure storage permission ─────────────────────────────────────
    final hasPermission = await LocalStorageService.hasStoragePermission();
    if (!hasPermission) {
      if (!mounted) return;
      final granted = await _showPermissionDialog();
      if (!granted) return;
    }

    // ── Step 2: ensure a save directory has been chosen ──────────────────────
    final saveDir = await LocalStorageService.getSaveDirectory();
    if (saveDir == null) {
      if (!mounted) return;
      final chosen = await LocalStorageService.pickSaveDirectory(context);
      if (chosen == null) return; // user cancelled
    }

    // ── Step 3: download ──────────────────────────────────────────────────────
    setState(() => _downloading.add(name));
    try {
      await LocalStorageService.downloadNote(url, widget.subjectAlias, name);
      if (mounted) {
        setState(() {
          _downloading.remove(name);
          _downloadedStatus[name] = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading.remove(name));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: VergeTheme.canvasBlack),
        );
      }
    }
  }

  /// Shows an explanation dialog and then requests the permission.
  /// Returns true if permission was ultimately granted.
  Future<bool> _showPermissionDialog() async {
    if (!mounted) return false;
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VergeTheme.canvasBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.folder_open_rounded, color: VergeTheme.jellyMint, size: 22),
          SizedBox(width: 10),
          Text('Storage access', style: TextStyle(color: VergeTheme.hazardWhite, fontSize: 17)),
        ]),
        content: Text(
          'Attenda needs permission to save notes to your device so you can open them offline.\n\nNo other files will be read or modified.',
          style: TextStyle(color: VergeTheme.dimGray, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now', style: TextStyle(color: VergeTheme.dimGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VergeTheme.jellyMint,
              foregroundColor: VergeTheme.canvasBlack,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;
    return await LocalStorageService.requestStoragePermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VergeTheme.canvasBlack,
      appBar: AppBar(
        backgroundColor: VergeTheme.canvasBlack,
        iconTheme: const IconThemeData(color: VergeTheme.hazardWhite),
        title: Text('${widget.subjectAlias} Notes', style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.hazardWhite)),
        actions: [
          PopupMenuButton<String>(
            color: VergeTheme.surfaceSlate,
            icon: const Icon(Icons.more_vert, color: VergeTheme.hazardWhite),
            onSelected: (value) async {
              if (value == 'change_dir') {
                await LocalStorageService.pickSaveDirectory(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Save location updated. New downloads will go there.'),
                      backgroundColor: VergeTheme.surfaceSlate,
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'change_dir',
                child: Row(children: [
                  Icon(Icons.folder_open_rounded, color: VergeTheme.jellyMint, size: 18),
                  SizedBox(width: 10),
                  Text('Change save location', style: TextStyle(color: VergeTheme.hazardWhite, fontSize: 14)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pdfs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final pdf = _pdfs[index];
          final name = pdf['name'] ?? 'Unknown PDF';
          final isDownloaded = _downloadedStatus[name] ?? false;
          final isDownloading = _downloading.contains(name);

          return InkWell(
            onTap: isDownloading ? null : () => _onPdfTap(pdf),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VergeTheme.canvasBlack,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDownloaded ? VergeTheme.jellyMint.withValues(alpha: 0.15) : VergeTheme.hazardWhite.withValues(alpha: 0.06)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDownloaded ? VergeTheme.jellyMint.withValues(alpha: 0.1) : VergeTheme.ultraviolet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(isDownloaded ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded, color: isDownloaded ? VergeTheme.jellyMint : VergeTheme.ultraviolet),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: VergeTheme.hazardWhite, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(isDownloaded ? 'Tap to open' : 'Tap to download', style: TextStyle(color: isDownloaded ? VergeTheme.jellyMint.withValues(alpha: 0.7) : VergeTheme.secondaryText, fontSize: 12)),
                ])),
                if (isDownloading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VergeTheme.jellyMint))
                else Icon(isDownloaded ? Icons.open_in_new_rounded : Icons.download_rounded, color: isDownloaded ? VergeTheme.jellyMint : VergeTheme.secondaryText, size: 20),
              ]),
            ),
          );
        },
      ),
    );
  }
}
