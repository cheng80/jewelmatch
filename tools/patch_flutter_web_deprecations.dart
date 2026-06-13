import 'dart:io';

void main(List<String> args) {
  final buildDir = args.isEmpty
      ? Directory('build/web')
      : Directory(args.first);
  if (!buildDir.existsSync()) {
    stderr.writeln('Web build directory not found: ${buildDir.path}');
    exitCode = 1;
    return;
  }

  final files = <File>[
    File('${buildDir.path}/flutter_bootstrap.js'),
    File('${buildDir.path}/flutter.js'),
    File('${buildDir.path}/main.dart.js'),
  ];

  var patchedFiles = 0;
  for (final file in files) {
    if (!file.existsSync()) continue;
    final before = file.readAsStringSync();
    final after = before
        .replaceAll(
          'typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u"',
          'typeof Intl.Segmenter<"u"',
        )
        .replaceAll(
          's.Intl.v8BreakIterator!=null&&s.Intl.Segmenter!=null',
          's.Intl.Segmenter!=null',
        );
    if (after == before) continue;
    file.writeAsStringSync(after);
    patchedFiles++;
    stdout.writeln('Patched ${file.path}');
  }

  if (patchedFiles == 0) {
    stdout.writeln('No Flutter web deprecated Intl checks found.');
  }
}
