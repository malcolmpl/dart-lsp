import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    final input = await stdin.transform(utf8.decoder).join();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(input) as Map<String, dynamic>;
    } catch (_) {
      exit(0);
    }

    final toolInput = json['tool_input'] as Map<String, dynamic>?;
    final filePath = toolInput?['file_path'] as String?;

    if (filePath == null || !filePath.endsWith('.dart')) exit(0);

    final file = File(filePath);
    if (!file.existsSync()) exit(0);

    // Find the package root (directory containing pubspec.yaml)
    Directory? packageRoot;
    var dir = file.parent;
    while (dir.path != dir.parent.path) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        packageRoot = dir;
        break;
      }
      dir = dir.parent;
    }

    // Track package root for Stop hook (dart fix --apply)
    if (packageRoot != null) {
      final sessionId = json['session_id'] as String? ?? 'default';
      final trackFile = File(
        '${Directory.systemTemp.path}/dart-lsp-packages-$sessionId.txt',
      );
      final existing = trackFile.existsSync()
          ? trackFile.readAsStringSync()
          : '';
      if (!existing.contains(packageRoot.path)) {
        trackFile.writeAsStringSync(
          '${packageRoot.path}\n',
          mode: FileMode.append,
        );
      }
    }

    // dart format on the specific file (dart fix moved to Stop hook)
    final formatResult = await Process.run('dart', ['format', filePath]);
    if (formatResult.exitCode != 0) {
      stderr.writeln('dart format failed: ${formatResult.stderr}');
    }
  } catch (e) {
    stderr.writeln('dart-post-edit error: $e');
  }

  exit(0);
}
