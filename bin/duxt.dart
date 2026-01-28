#!/usr/bin/env dart

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:duxt/src/cli/create_command.dart';
import 'package:duxt/src/cli/dev_command.dart';
import 'package:duxt/src/cli/build_command.dart';
import 'package:duxt/src/cli/generate_command.dart';
import 'package:duxt/src/cli/g_command.dart';
import 'package:duxt/src/cli/start_command.dart';
import 'package:duxt/src/cli/scaffold_command.dart';

const version = '0.2.0';

void main(List<String> args) async {
  // Handle version flag
  if (args.contains('--version') || args.contains('-v')) {
    print('Duxt v$version');
    exit(0);
  }

  final runner = CommandRunner<int>(
    'duxt',
    '''
Duxt v$version - A Nuxt-like meta-framework for Jaspr

Project:
  create <name>        Create a new Duxt project

Development:
  dev [--port]         Start dev server with hot reload
  start [--port]       Start production server

Build:
  build                Build for production
  generate             Generate static site (SSG)

Generate:
  g <type> <name>      Generate module, page, component, model, api, layout
  scaffold <name>      Generate full module with CRUD

Run "duxt help <command>" for more information.
''',
  )
    ..addCommand(CreateCommand())
    ..addCommand(DevCommand())
    ..addCommand(StartCommand())
    ..addCommand(BuildCommand())
    ..addCommand(GenerateCommand())
    ..addCommand(GCommand())
    ..addCommand(ScaffoldCommand());

  try {
    final result = await runner.run(args);
    exit(result ?? 0);
  } on UsageException catch (e) {
    print(e);
    exit(64);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
