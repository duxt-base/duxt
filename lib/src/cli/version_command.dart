import 'package:args/command_runner.dart';

/// Command to show version
class VersionCommand extends Command<int> {
  final String version;

  VersionCommand(this.version);

  @override
  final name = 'version';

  @override
  final description = 'Show Duxt version';

  @override
  int run() {
    print('Duxt v$version');
    return 0;
  }
}
