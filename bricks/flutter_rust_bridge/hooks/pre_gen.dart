import 'dart:convert';
import 'dart:math';

import 'package:mason/mason.dart';
import 'dart:io';
import 'package:crclib/crclib.dart';
import 'package:crclib/catalog.dart';
import 'package:mustache_template/mustache.dart' show LambdaFunction;

/** Partially reproduced from https://gitlab.com/kornelski/cargo-xcode */
class Generator {
  final ParametricCrc crc;
  final int base;

  const Generator({required this.crc, required this.base});

  factory Generator.from(String id) {
    final crc = Crc64Ecma182();
    final base = crc.convert(utf8.encode(id));
    return Generator(crc: crc, base: (base as dynamic)._intValue);
  }

  String id(String kind, String name) {
    final kind_ = crc.convert([this.base]..addAll(utf8.encode(kind)));
    final name_ = crc.convert(utf8.encode(name));
    final ret = 'CA60' + kind_.toString().padLeft(8, '0') + name_.toString().padLeft(12, '0');
    return ret.substring(0, max(ret.length, 24));
  }
}

void run(HookContext context) async {
  final v = context.vars;
  final String name = v['name'];
  final logger = context.logger;
  if (await File('$name/Cargo.toml').exists() && !logger.confirm('Crate $name already exists, continue?')) {
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

  final gen = Generator.from(v['name']);
  final LambdaFunction id = (context) => gen.id(
        context.lookup('kind')?.toString() ?? '',
        context.renderString(),
      );
  final justfile = File('justfile');
  v['previous_justfile'] = '';
  v['justfile'] = true;
  v['id'] = id;
  final tasks = <String>[v['name']];
  managed:
  if (await justfile.exists()) {
    final justfileContent = await justfile.readAsString();
    const barrier = '# end-header';
    final idx = justfileContent.indexOf(barrier);
    if (idx != -1) {
      const len = barrier.length;
      v['previous_justfile'] = justfileContent.substring(idx + len);
    }
    if (!justfileContent.contains('@mason: flutter_rust_bridge')) {
      v['justfile'] = false;
      break managed;
    }

    final recipePattern = RegExp(r'gen_(.+):');
    tasks.addAll(recipePattern.allMatches(justfileContent).map((e) => e.group(1)!));
    logger.alert('Detected justfile previously created by this brick. It is recommended to overwrite justfile.');
  }
  v['tasks'] = tasks;
}
