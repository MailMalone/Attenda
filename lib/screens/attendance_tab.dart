import 'package:flutter/material.dart';
import '../theme.dart';

class AttendanceTab extends StatelessWidget {
  final List<dynamic> attendanceData;
  final RefreshCallback onRefresh;

  const AttendanceTab({Key? key, required this.attendanceData, required this.onRefresh}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (attendanceData.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: VergeTheme.absoluteBlack,
        backgroundColor: VergeTheme.jellyMint,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_outlined, color: VergeTheme.secondaryText, size: 40),
                  const SizedBox(height: 12),
                  Text('NO ATTENDANCE DATA FOUND.', style: VergeTheme.monoTimestamp),
                  const SizedBox(height: 6),
                  Text('PULL DOWN TO REFRESH', style: VergeTheme.monoTimestamp),
                ],
              ),
            ),
          ],
        ),
      );
    }

    int atRiskCount = 0;
    for (final item in attendanceData) {
      final conducted = int.tryParse(item['conducted'].toString()) ?? 0;
      final attended = int.tryParse(item['attended'].toString()) ?? 0;
      final percentage = conducted > 0 ? (attended / conducted * 100) : 0.0;
      if (percentage < 85) atRiskCount++;
    }

    String funnyMessage = '';
    if (atRiskCount == 0) funnyMessage = "Perfect! You're safe... for now.";
    else if (atRiskCount == 1) funnyMessage = "One class in the danger zone. Don't slip up!";
    else if (atRiskCount == 2) funnyMessage = "Two classes short. Time to set some alarms.";
    else if (atRiskCount == 3) funnyMessage = "Three classes short?! Your bed is too comfortable.";
    else funnyMessage = "4+ classes? The professor doesn't even know your face anymore fam.";

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: VergeTheme.absoluteBlack,
      backgroundColor: VergeTheme.jellyMint,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: attendanceData.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VergeTheme.surfaceSlate,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VergeTheme.hazardWhite.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        atRiskCount == 0 ? Icons.shield_rounded : Icons.warning_amber_rounded,
                        color: atRiskCount == 0 ? VergeTheme.jellyMint : VergeTheme.ultraviolet,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          atRiskCount == 0 ? 'ALL CLEAR' : '$atRiskCount CLASSES AT RISK',
                          style: VergeTheme.eyebrowAllCaps.copyWith(
                            color: atRiskCount == 0 ? VergeTheme.jellyMint : VergeTheme.ultraviolet,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    funnyMessage,
                    style: TextStyle(color: VergeTheme.secondaryText, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            );
          }

          final item = attendanceData[index - 1];
          final rawName = item['fsubname']?.toString() ?? '';
          
          String extractedCode = '';
          final nameParts = rawName.split('-');
          final cleanParts = nameParts.where((p) {
            final t = p.trim();
            if (!t.contains(' ') && RegExp(r'\d').hasMatch(t) && RegExp(r'[A-Za-z]').hasMatch(t) && t.length >= 5 && t.length <= 10) {
              extractedCode = t;
              return false;
            }
            return true;
          });
          final cleanName = cleanParts.join(' - ').trim();
          final displayCode = extractedCode.isNotEmpty ? extractedCode : item['fsubcode'].toString();

          final conducted = int.tryParse(item['conducted'].toString()) ?? 0;
          final attended = int.tryParse(item['attended'].toString()) ?? 0;
          final percentage = conducted > 0 ? (attended / conducted * 100) : 0.0;

          final bool isSafe = percentage >= 85;
          final int bunksAllowed = isSafe ? ((attended - 0.85 * conducted) / 0.85).floor() : 0;
          final int attendNeeded = !isSafe ? ((0.85 * conducted - attended) / 0.15).ceil() : 0;

          final Color pctColor = percentage < 75
              ? VergeTheme.ultraviolet
              : (percentage < 85 ? Colors.orangeAccent : VergeTheme.jellyMint);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: VergeTheme.canvasBlack,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VergeTheme.hazardWhite, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayCode.toUpperCase(),
                    style: VergeTheme.eyebrowAllCaps.copyWith(color: VergeTheme.jellyMint),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cleanName.toUpperCase(),
                    style: VergeTheme.headingSmall.copyWith(color: VergeTheme.hazardWhite),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stat('CONDUCTED', conducted.toString()),
                      _stat('ATTENDED', attended.toString()),
                      _stat('PERCENTAGE', '${percentage.toStringAsFixed(1)}%', color: pctColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percentage / 100).clamp(0.0, 1.0),
                      backgroundColor: VergeTheme.surfaceSlate,
                      valueColor: AlwaysStoppedAnimation<Color>(pctColor),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: VergeTheme.canvasBlack,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSafe ? VergeTheme.jellyMint : VergeTheme.ultraviolet,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: isSafe ? VergeTheme.jellyMint : VergeTheme.ultraviolet,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSafe
                                ? 'SAFE TO BUNK $bunksAllowed MORE CLASS${bunksAllowed == 1 ? '' : 'ES'} (85% GOAL)'
                                : 'ATTEND $attendNeeded MORE CLASS${attendNeeded == 1 ? '' : 'ES'} TO REACH 85%',
                            style: VergeTheme.monoTimestamp.copyWith(
                              color: isSafe ? VergeTheme.jellyMint : VergeTheme.ultraviolet,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, {Color color = VergeTheme.hazardWhite}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VergeTheme.monoTimestamp.copyWith(color: VergeTheme.secondaryText, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: VergeTheme.largeHeadline.copyWith(color: color, fontSize: 24)),
      ],
    );
  }
}
