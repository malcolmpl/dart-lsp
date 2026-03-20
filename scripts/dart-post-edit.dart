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

    // dart fix --apply on the package (if pubspec.yaml found)
    if (packageRoot != null) {
      final fixResult = await Process.run(
        'dart',
        ['fix', '--apply'],
        workingDirectory: packageRoot.path,
      );
      if (fixResult.exitCode != 0) {
        stderr.writeln('dart fix failed: ${fixResult.stderr}');
      }
    }

    // dart format on the specific file
    final formatResult = await Process.run('dart', ['format', filePath]);
    if (formatResult.exitCode != 0) {
      stderr.writeln('dart format failed: ${formatResult.stderr}');
    }
  } catch (e) {
    stderr.writeln('dart-post-edit error: $e');
  }

  exit(0);
}
