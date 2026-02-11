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
import 'package:duxt/src/cli/docs_command.dart';
import 'package:duxt/src/version.dart';

const minJasprVersion = '0.22.2';

void main(List<String> args) async {
  final version = packageVersion;

  // Handle version flag
  if (args.contains('--version') || args.contains('-v')) {
    print('Duxt v$version');
    exit(0);
  }

  // Check for updates in background (non-blocking)
  if (args.isNotEmpty && !args.contains('update')) {
    checkForUpdates(version);
  }

  // Check jaspr version for commands that need it
  final jasprCommands = ['dev', 'build', 'preview', 'start', 'generate', 'clean'];
  final command = args.isNotEmpty ? args.first : '';
  if (jasprCommands.contains(command)) {
    await checkJasprVersion();
  }

  final runner = CommandRunner<int>(
    'duxt',
    '''
Duxt v$version - A meta-framework for Jaspr

Project:
  create <name>        Create a new Duxt project
  create <name> --desktop  Create as desktop app (Tauri + SPA)
  update               Update Duxt CLI to latest version
  version              Show version

Development:
  dev [--port]         Start dev server with hot reload (jaspr serve)
  dev --desktop        Dev server in a native desktop window (Tauri)
  start [--port]       Start production server (serves built files)
  preview [--port]     Preview production build locally

Build:
  build [--target]     Build for production deployment (jaspr build)
  build desktop        Build as native desktop app (Tauri)
  generate             Generate static site (SSG only, no server)

Generators:
  g <type> <name>      Generate module, page, component, model, api, layout
  scaffold <name>      Generate full module with CRUD
  d <type> <name>      Delete module, page, component, model, or api

Documentation:
  docs generate        Generate API docs from code
  docs page <name>     Create a documentation page
  docs tutorial <name> Create a tutorial page

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
    ..addCommand(DocsCommand())
    ..addCommand(UpdateCommand(version))
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

/// Check if jaspr CLI is installed and meets minimum version requirement
Future<void> checkJasprVersion() async {
  try {
    final result = await Process.run('jaspr', ['--version']);
    if (result.exitCode != 0) {
      print('\x1B[31m✗\x1B[0m Jaspr CLI not found.');
      print('  Install it with: dart pub global activate jaspr');
      exit(1);
    }

    // Parse version from output - jaspr prints version on its own line
    // The output may include package resolution, so look for a line that's just a version
    final output = result.stdout.toString();
    final lines = output.split('\n');
    String? installedVersion;

    // Find a line that contains only a version number (e.g., "0.22.2")
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^0\.\d+\.\d+$').hasMatch(trimmed)) {
        installedVersion = trimmed;
        break;
      }
    }

    if (installedVersion == null) {
      print('\x1B[33m!\x1B[0m Could not determine Jaspr version');
      return;
    }

    if (!_isVersionSatisfied(installedVersion, minJasprVersion)) {
      print('');
      print('\x1B[31m✗\x1B[0m Jaspr version $installedVersion is not supported.');
      print('  Please update to the latest version.');
      print('');
      print('  Run: jaspr update');
      print('');
      exit(1);
    }
  } catch (e) {
    print('\x1B[31m✗\x1B[0m Jaspr CLI not found.');
    print('  Install it with: dart pub global activate jaspr');
    exit(1);
  }
}

/// Compare semantic versions. Returns true if installed >= required.
bool _isVersionSatisfied(String installed, String required) {
  final installedParts = installed.split('.').map(int.parse).toList();
  final requiredParts = required.split('.').map(int.parse).toList();

  for (var i = 0; i < 3; i++) {
    final inst = i < installedParts.length ? installedParts[i] : 0;
    final req = i < requiredParts.length ? requiredParts[i] : 0;

    if (inst > req) return true;
    if (inst < req) return false;
  }
  return true; // Equal versions
}
