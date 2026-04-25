import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _prefKeySaveDir = 'notes_save_directory';

  // ─── Permission ───────────────────────────────────────────────────────────

  /// Returns true when the app can write to external storage.
  /// On Android 11+ (API 30+) this requires MANAGE_EXTERNAL_STORAGE.
  /// On Android ≤10 it requires WRITE_EXTERNAL_STORAGE.
  static Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid11OrAbove()) {
        return await Permission.manageExternalStorage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true; // iOS / other platforms use sandboxed access
  }

  /// Requests storage permission and returns whether it was granted.
  /// On Android 11+ the user is taken to the system settings screen.
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    if (await _isAndroid11OrAbove()) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return status.isGranted;
    } else {
      final status = await Permission.storage.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return status.isGranted;
    }
  }

  // ─── Save directory ───────────────────────────────────────────────────────

  /// Returns the user-chosen save path, or null if never set.
  static Future<String?> getSaveDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeySaveDir);
  }

  /// Persists a user-chosen save path.
  static Future<void> setSaveDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySaveDir, path);
  }

  /// Clears the saved directory so the user is prompted again next time.
  static Future<void> clearSaveDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeySaveDir);
  }

  /// Shows a bottom sheet that lets the user choose a save location.
  /// Returns the chosen path, or null if the user cancelled.
  ///
  /// [context] must be a valid, mounted BuildContext.
  static Future<String?> pickSaveDirectory(BuildContext context) async {
    // Build a list of candidate directories
    final candidates = <_DirOption>[];

    // 1. App-private external storage (no permission needed, always available)
    final extAppDir = await getExternalStorageDirectory();
    if (extAppDir != null) {
      candidates.add(_DirOption(
        label: 'App folder (recommended)',
        sublabel: extAppDir.path,
        path: '${extAppDir.path}/Attenda/Notes',
        icon: Icons.phone_android_rounded,
      ));
    }

    // 2. Public Downloads folder
    candidates.add(_DirOption(
      label: 'Downloads',
      sublabel: '/storage/emulated/0/Download/Attenda',
      path: '/storage/emulated/0/Download/Attenda',
      icon: Icons.download_rounded,
    ));

    // 3. Public Documents folder
    candidates.add(_DirOption(
      label: 'Documents',
      sublabel: '/storage/emulated/0/Documents/Attenda',
      path: '/storage/emulated/0/Documents/Attenda',
      icon: Icons.folder_rounded,
    ));

    // 4. SD Card (if present)
    try {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null && extDirs.length > 1) {
        final sdCard = extDirs[1];
        candidates.add(_DirOption(
          label: 'SD Card',
          sublabel: '${sdCard.path}/Attenda',
          path: '${sdCard.path}/Attenda',
          icon: Icons.sd_card_rounded,
        ));
      }
    } catch (_) {}

    if (!context.mounted) return null;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SaveDirPicker(options: candidates),
    );

    if (chosen != null) {
      await setSaveDirectory(chosen);
    }
    return chosen;
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  static Future<bool> _isAndroid11OrAbove() async {
    // permission_handler exposes the OS version via its own API
    if (await Permission.manageExternalStorage.status !=
        PermissionStatus.denied) {
      return true;
    }
    // Fallback: check if the permission even exists (it doesn't pre-API-30)
    return (await Permission.manageExternalStorage.request()) !=
        PermissionStatus.denied;
  }

  /// Resolves (and creates if needed) the save directory for a subject.
  static Future<Directory> _getSubjectDirectory(String subjectAlias) async {
    final baseRaw = await getSaveDirectory();
    final safeAlias = subjectAlias.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    late Directory dir;
    if (baseRaw != null) {
      dir = Directory('$baseRaw/$safeAlias');
    } else {
      // Fallback to app-private external dir if nothing was chosen yet
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) throw Exception('Could not access external storage');
      dir = Directory('${extDir.path}/Attenda/$safeAlias');
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ─── Public API (unchanged signatures) ───────────────────────────────────

  static Future<bool> isNoteDownloaded(
      String subjectAlias, String fileName) async {
    try {
      final dir = await _getSubjectDirectory(subjectAlias);
      return await File('${dir.path}/$fileName').exists();
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getLocalNotePath(
      String subjectAlias, String fileName) async {
    try {
      final dir = await _getSubjectDirectory(subjectAlias);
      final file = File('${dir.path}/$fileName');
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> downloadNote(
      String url, String subjectAlias, String fileName) async {
    final dir = await _getSubjectDirectory(subjectAlias);
    final file = File('${dir.path}/$fileName');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    }
    throw Exception('Failed to download note: HTTP ${response.statusCode}');
  }
}

// ─── Private UI helpers ───────────────────────────────────────────────────

class _DirOption {
  final String label;
  final String sublabel;
  final String path;
  final IconData icon;
  const _DirOption(
      {required this.label,
      required this.sublabel,
      required this.path,
      required this.icon});
}

class _SaveDirPicker extends StatelessWidget {
  final List<_DirOption> options;
  const _SaveDirPicker({required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose save location',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Notes will be saved here on your device.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) => _OptionTile(opt: opt)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Center(
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _DirOption opt;
  const _OptionTile({required this.opt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.pop(context, opt.path),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(opt.icon, color: const Color(0xFF60A5FA), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(opt.sublabel,
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[700], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
