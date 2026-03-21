import 'dart:convert';
import 'dart:io';

/// Runs `dart fix --apply` on all packages that had .dart files edited
/// during the session. Triggered by the Stop hook.
void main() async {
  try {
    final input = await stdin.transform(utf8.decoder).join();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(input) as Map<String, dynamic>;
    } catch (_) {
      exit(0);
    }

    // Skip if this is a re-entry from a previous stop hook
    if (json['stop_hook_active'] == true) exit(0);

    final sessionId = json['session_id'] as String? ?? 'default';
    final trackFile = File(
      '${Directory.systemTemp.path}/dart-lsp-packages-$sessionId.txt',
    );

    if (!trackFile.existsSync()) exit(0);

    final roots = trackFile
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toSet();

    // Clean up tracking file
    trackFile.deleteSync();

    if (roots.isEmpty) exit(0);

    // Run dart fix --apply on each affected package
    for (final root in roots) {
      if (!Directory(root).existsSync()) continue;
      final fixResult = await Process.run('dart', [
        'fix',
        '--apply',
      ], workingDirectory: root);
      if (fixResult.exitCode != 0) {
        stderr.writeln('dart fix failed in $root: ${fixResult.stderr}');
      }
    }
  } catch (e) {
    stderr.writeln('dart-stop-fix error: $e');
  }

  exit(0);
}
