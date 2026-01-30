#!/usr/bin/env dart

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:duxt/src/cli/create_command.dart';
import 'package:duxt/src/cli/dev_command.dart';
import 'package:duxt/src/cli/build_command.dart';
import 'package:duxt/src/cli/start_command.dart';
import 'package:duxt/src/cli/generate_command.dart';
import 'package:duxt/src/cli/g_command.dart';
import 'package:duxt/src/cli/preview_command.dart';
import 'package:duxt/src/cli/scaffold_command.dart';
import 'package:duxt/src/cli/delete_command.dart';
import 'package:duxt/src/cli/info_command.dart';
import 'package:duxt/src/cli/doctor_command.dart';
import 'package:duxt/src/cli/clean_command.dart';
import 'package:duxt/src/cli/update_command.dart';
import 'package:duxt/src/cli/version_command.dart';

const version = '0.3.8';

void main(List<String> args) async {
  // Handle version flag
  if (args.contains('--version') || args.contains('-v')) {
    print('Duxt v$version');
    exit(0);
  }

  // Check for updates in background (non-blocking)
  if (args.isNotEmpty && !args.contains('update')) {
    checkForUpdates(version);
  }

  final runner = CommandRunner<int>(
    'duxt',
    '''
Duxt v$version - A meta-framework for Jaspr

Project:
  create <name>        Create a new Duxt project
  update               Update Duxt CLI to latest version
  version              Show version

Development:
  dev [--port]         Start dev server with hot reload (jaspr serve)
  start [--port]       Start production server (serves built files)
  preview [--port]     Preview production build locally

Build:
  build [--target]     Build for production deployment (jaspr build)
  generate             Generate static site (SSG only, no server)

Generators:
  g <type> <name>      Generate module, page, component, model, api, layout
  scaffold <name>      Generate full module with CRUD
  d <type> <name>      Delete module, page, component, model, or api

Utilities:
  info                 Show project information
  doctor               Show environment and project diagnostics
  clean                Clean build artifacts (also runs jaspr clean)

Run "duxt help <command>" for more information.
''',
  )
    ..addCommand(CreateCommand())
    ..addCommand(DevCommand())
    ..addCommand(StartCommand())
    ..addCommand(BuildCommand())
    ..addCommand(PreviewCommand())
    ..addCommand(GenerateCommand())
    ..addCommand(GCommand())
    ..addCommand(ScaffoldCommand())
    ..addCommand(DeleteCommand())
    ..addCommand(InfoCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(CleanCommand())
    ..addCommand(UpdateCommand())
    ..addCommand(VersionCommand(version));

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
