import 'package:mason/mason.dart';
import 'dart:io';

final logger = Logger();

const system = Process.run;
bool success(ProcessResult proc, [Function(String)? onError]) {
  onError ??= logger.err;
  final success = proc.exitCode == 0;
  if (!success) {
    print('');
    onError('Process PID ${proc.pid} failed (code: ${proc.exitCode})');
    logger.info('Stderr: ${proc.stderr}');
    print('');
  }
  return success;
}

Future<bool> fileContains(String path, String needle) async {
  final file = File(path);
  return await file.exists() && (await file.readAsString()).contains(needle);
}

Future<bool> which(String command) async {
  final ProcessResult res;
  if (Platform.isWindows) {
    res = await system('powershell', ['-noprofile', '-c' 'where.exe $command']);
  } else {
    res = await system('sh', ['-c', 'which $command']);
  }
  return res.exitCode == 0;
}

Future<String?> tryRead(String path, Function(String) onError) async {
  try {
    return await File(path).readAsString();
  } catch (err) {
    onError('$path not found.');
    return null;
  }
}

void run(HookContext context) async {
  final v = context.vars;
  final logger = context.logger;

  if (await which('flutter')) {
    final pubspec = await tryRead('pubspec.yaml', logger.err);
    if (pubspec != null && !pubspec.contains('flutter_rust_bridge')) {
      final prog = logger.progress('Installing flutter_rust_bridge');
      if (!success(await system('flutter', ['pub', 'add', 'flutter_rust_bridge']))) {
        logger.err(
          'Could not add required library flutter_rust_bridge, '
          'please run `flutter pub add flutter_rust_bridge` to add it.',
        );
        prog.fail();
      } else {
        prog.complete();
      }
    } else if (pubspec == null) {
      logger.info('= Please create the brick at the root of your Flutter project.');
      exit(1);
    }
  }
  if (await which('cargo')) {
    final cwd = v['name'];
    final prog = logger.progress('Running cargo-xcode in $cwd');
    if (!(success(await system('cargo', ['install', 'cargo-xcode'])) &&
        success(await system('cargo', ['xcode'], workingDirectory: './$cwd')))) {
      logger.err('Could not initialize Xcode project for $cwd');
      prog.fail();
    } else {
      prog.complete();
    }
  } else {
    logger.warn('Could not perform cargo-related setup steps.');
    logger.info("""
= Some files may be missing.
= Please install `rustup` and recreate this brick to generate the necessary files.
""");
  }
  final androidManifest = File('android/app/build.gradle');
  if (await androidManifest.exists() && (await androidManifest.readAsString()).contains('cargo-ndk')) {
    logger.warn('Manual setup for Android is required.');
    logger.info('= Please check out http://cjycode.com/flutter_rust_bridge/integrate/android.html for more details.');
    print('');
  }
  if (v['macos'] == true || v['ios'] == true) {
    logger.warn('Manual setup for MacOS/iOS may be required.');
    logger.info('= Please check out http://cjycode.com/flutter_rust_bridge/integrate/ios.html for more details.');
    print('');
  }
  if (!await fileContains('linux/CMakeLists.txt', 'include(./rust.cmake)')) {
    logger.warn('Manual setup for Linux is required.');
    logger.info("""
= Add the following line to linux/CMakeLists.txt to enable integration with `flutter run`:
=     include(./rust.cmake)
""");
  }

  if (!await fileContains('windows/CMakeLists.txt', 'include(./rust.cmake)')) {
    logger.warn('Manual setup for Windows is required.');
    logger.info("""
= Add the following line to windows/CMakeLists.txt to enable integration with `flutter run`:
=     include(./rust.cmake)
""");
  }
}
