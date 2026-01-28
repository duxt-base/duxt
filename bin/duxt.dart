#!/usr/bin/env dart

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:duxt/src/cli/create_command.dart';
import 'package:duxt/src/cli/dev_command.dart';
import 'package:duxt/src/cli/build_command.dart';
import 'package:duxt/src/cli/generate_command.dart';
import 'package:duxt/src/cli/add_command.dart';
import 'package:duxt/src/cli/g_command.dart';
import 'package:duxt/src/cli/start_command.dart';
import 'package:duxt/src/cli/scaffold_command.dart';

void main(List<String> args) async {
  final runner = CommandRunner<int>(
    'duxt',
    'Duxt - A Nuxt-like meta-framework for Jaspr',
  )
    ..addCommand(CreateCommand())
    ..addCommand(DevCommand())
    ..addCommand(StartCommand())
    ..addCommand(BuildCommand())
    ..addCommand(GenerateCommand())
    ..addCommand(AddCommand())
    ..addCommand(GCommand())
    ..addCommand(ScaffoldCommand());

  try {
    final result = await runner.run(args);
    exit(result ?? 0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
