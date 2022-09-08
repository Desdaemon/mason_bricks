import 'package:path/path.dart' as p;
import 'package:mason/mason.dart';
import 'dart:io';

Stream<String> findCrates([String directory = '']) async* {
  await for (final sub in Directory(directory).list()) {
    if (await File(p.join(sub.path, 'Cargo.toml')).exists()) {
      yield p.basename(sub.path);
    }
  }
}

const tag = '@mason: flutter_rust_bridge';

Future<bool> managed(String path, {bool replace = true}) async {
  final file = File(path);
  final fileExists = await file.exists();
  final res = !fileExists || (await file.readAsString()).contains(tag);
  if (res && fileExists) await file.delete();
  return res;
}

void run(HookContext context) async {
  final v = context.vars;
  final name = v['name'];
  final logger = context.logger;
  if (v['wasm'] == true) {
    v['bridge_def'] = logger.prompt("What is the definition file's name?", defaultValue: 'bridge_definitions');
  }
  if (await (File('$name/Cargo.toml').exists()) && !logger.confirm('Crate "$name" already exists, continue?')) {
    exit(0);
  }

  final dartManifest = File('.metadata');
  if (await dartManifest.exists()) {
    final manifestContent = await dartManifest.readAsString();
    final packagePattern = RegExp(r'platform: (.+)');
    for (final match in packagePattern.allMatches(manifestContent)) {
      final platform = match.group(1)!.trim();
      v[platform] = true;
    }
  }

  final crates = await findCrates().toSet()
    ..add(v['name']);
  v['previous_justfile'] = '';
  v['justfile'] = await managed('justfile');
  v['cmake_linux'] = await managed('linux/rust.cmake');
  v['cmake_windows'] = await managed('windows/rust.cmake');
  v['crates'] = crates.toList();
  v['tag'] = tag;
}
