import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import '../cache_service.dart';
import '../models/student_data.dart';
import 'attendance_tab.dart';
import 'ia_marks_tab.dart';
import 'timetable_tab.dart';
import 'bunk_tab.dart';
import 'study_tab.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  final StudentData studentData;
  final String regno;
  final String passwd;

  const DashboardScreen({
    Key? key,
    required this.studentData,
    required this.regno,
    required this.passwd,
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StudentData _currentData;
  int _currentIndex = 0;
  bool _isRefreshing = false;
  String? _lastUpdatedLabel;
  Timer? _updateTimer;

  // Tabs that should NOT show the refresh button (timetable, bunk, study)
  static const _noRefreshTabs = {2, 3, 4};

  @override
  void initState() {
    super.initState();
    _currentData = widget.studentData;
    _loadLastUpdatedLabel();
    // Update the "Last Updated" label every minute to keep it accurate
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadLastUpdatedLabel();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLastUpdatedLabel() async {
    final label = await CacheService.lastUpdatedLabel();
    if (mounted) setState(() => _lastUpdatedLabel = label?.toUpperCase());
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final api = ApiService();
      final fresh = await api.loginAndGetData(widget.regno, widget.passwd);
      await CacheService.saveStudentData(fresh);
      final label = await CacheService.lastUpdatedLabel();
      if (mounted) {
        setState(() { _currentData = fresh; _lastUpdatedLabel = label?.toUpperCase(); });
        _showSnack('DATA REFRESHED SUCCESSFULLY', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          "REFRESH FAILED: ${e.toString().replaceAll('Exception: ', '').toUpperCase()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: isError ? VergeTheme.ultraviolet : VergeTheme.jellyMint,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: VergeTheme.monoTimestamp.copyWith(color: VergeTheme.hazardWhite, fontSize: 12))),
      ]),
      backgroundColor: VergeTheme.surfaceSlate,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: (isError ? VergeTheme.ultraviolet : VergeTheme.jellyMint).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      duration: Duration(seconds: isError ? 3 : 2),
      margin: const EdgeInsets.all(12),
    ));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('regno');
    await prefs.remove('passwd');
    await CacheService.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AttendanceTab(attendanceData: _currentData.attendance, onRefresh: _refresh),
      IaMarksTab(iaMarksData: _currentData.iaMarks, onRefresh: _refresh),
      TimetableTab(studentData: _currentData),
      BunkTab(attendanceData: _currentData.attendance),
      StudyTab(attendanceData: _currentData.attendance),
    ];

    return Scaffold(
      backgroundColor: VergeTheme.canvasBlack,
      appBar: _buildAppBar(),
      body: tabs[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: VergeTheme.canvasBlack,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ATTENDA',
              style: VergeTheme.tertiaryDisplay.copyWith(fontSize: 32, height: 1.0, letterSpacing: 0)),
          if (_lastUpdatedLabel != null)
            Text(_lastUpdatedLabel!,
                style: VergeTheme.monoTimestamp),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: VergeTheme.hazardWhite, height: 1),
      ),
      actions: [
        if (!_noRefreshTabs.contains(_currentIndex))
          _isRefreshing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VergeTheme.jellyMint),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: VergeTheme.jellyMint),
                  tooltip: 'Refresh data',
                  onPressed: _refresh,
                ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: VergeTheme.ultraviolet, size: 22),
          tooltip: 'Logout',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: VergeTheme.surfaceSlate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: VergeTheme.ultraviolet, width: 1),
                ),
                title: Text('LOGOUT',
                    style: VergeTheme.headingSmall.copyWith(color: VergeTheme.hazardWhite)),
                content: Text(
                  'This will clear your saved credentials. You will need to sign in again.',
                  style: VergeTheme.bodyRelaxed.copyWith(color: VergeTheme.mutedText),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('CANCEL', style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.secondaryText)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('LOGOUT',
                        style: VergeTheme.monoButtonLabel.copyWith(color: VergeTheme.ultraviolet)),
                  ),
                ],
              ),
            );
            if (confirm == true) _logout();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: VergeTheme.canvasBlack,
        border: Border(top: BorderSide(color: VergeTheme.hazardWhite, width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: VergeTheme.canvasBlack,
        selectedItemColor: VergeTheme.jellyMint,
        unselectedItemColor: VergeTheme.secondaryText,
        currentIndex: _currentIndex,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: VergeTheme.monoButtonLabel.copyWith(fontSize: 10, letterSpacing: 0.5),
        unselectedLabelStyle: VergeTheme.monoButtonLabel.copyWith(fontSize: 10, letterSpacing: 0.5),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            activeIcon: Icon(Icons.fact_check),
            label: 'ATTENDANCE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grade_outlined),
            activeIcon: Icon(Icons.grade),
            label: 'IA MARKS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'TIMETABLE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate_outlined),
            activeIcon: Icon(Icons.calculate),
            label: 'BUNK',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'STUDY',
          ),
        ],
      ),
    );
  }
}
