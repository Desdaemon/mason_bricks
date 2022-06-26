import 'package:mason/mason.dart';
import 'dart:io';

Future<bool> which(String command) async {
  final ProcessResult res;
  if (Platform.isWindows) {
    res = await Process.run('powershell', ['-noprofile', '-c' 'where.exe $command']);
  } else {
    res = await Process.run('sh', ['-c', 'which $command']);
  }
  return res.exitCode == 0;
}

Future<String?> tryRead(String path, Function(String) onError) async {
  try {
    return await File(path).readAsString();
  } catch (err, st) {
    onError(err.toString());
    onError('Backtrace:\n$st');
    return null;
  }
}

void run(HookContext context) async {
  final v = context.vars;
  final logger = context.logger;
  final String? pubspec;
  final success = (ProcessResult res) {
    if (res.exitCode != 0) {
      logger.warn('Process ${res.pid} failed!');
      logger.detail('= Stderr:\n${res.stderr}');
      logger.info('');
    }
    return res.exitCode == 0;
  };

  if (await which('flutter') &&
      (pubspec = await tryRead('pubspec.yaml', logger.err)) != null &&
      !pubspec!.contains('flutter_rust_bridge')) {
    final prog = logger.progress('Installing flutter_rust_bridge');
    if (!success(await Process.run(
      'flutter',
      ['pub', 'add', 'flutter_rust_bridge'],
    ))) {
      logger.err(
        'Could not add required library flutter_rust_bridge, '
        'please run `flutter pub add flutter_rust_bridge` to add it.',
      );
      prog.fail();
    } else {
      prog.complete();
    }
  }
  if (await which('cargo')) {
    final cwd = v['name'];
    final prog = logger.progress('Running cargo-xcode in $cwd');
    if (!(success(await Process.run(
          'cargo',
          ['install', 'cargo-xcode'],
        )) &&
        success(await Process.run(
          'cargo',
          ['xcode'],
          workingDirectory: './$cwd',
        )))) {
      logger.err('Could not initialize Xcode project for $cwd');
      prog.fail();
    } else {
      prog.complete();
    }
  }
  if (v['macos'] == true || v['ios'] == true) {
    logger.alert('MacOS and/or iOS support detected, however manual setup is required.');
    logger.info('= Please check out http://cjycode.com/flutter_rust_bridge/integrate/ios.html for more details.');
  }
}
