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

  // 치환 문자열이 짧아지면 같은 줄 뒤쪽 문자의 column이 밀려 source map(Sentry 업로드용)이 어긋난다.
  // 그래서 치환 뒤에 ASCII 공백을 붙여 원본과 같은 길이를 유지한다. 공백은 JS 의미를 바꾸지 않는다.
  String keepLength(String source, String from, String to) =>
      source.replaceAll(from, to.padRight(from.length));

  var patchedFiles = 0;
  for (final file in files) {
    if (!file.existsSync()) continue;
    final before = file.readAsStringSync();
    var after = keepLength(
      before,
      'typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u"',
      'typeof Intl.Segmenter<"u"',
    );
    after = keepLength(
      after,
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
