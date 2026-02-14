import 'package:test/test.dart';
import 'package:duxt/src/core/build_events.dart';

void main() {
  group('BuildEventType', () {
    test('has all expected values', () {
      expect(BuildEventType.values, hasLength(3));
      expect(BuildEventType.values, contains(BuildEventType.started));
      expect(BuildEventType.values, contains(BuildEventType.succeeded));
      expect(BuildEventType.values, contains(BuildEventType.failed));
    });
  });

  group('BuildEventClient', () {
    test('can be created with callbacks', () {
      final events = <BuildEventType>[];
      final client = BuildEventClient(
        onBuildEvent: (type, {String? error}) => events.add(type),
      );
      expect(client, isNotNull);
    });

    test('connect returns false when no daemon is running', () async {
      final client = BuildEventClient(
        onBuildEvent: (type, {String? error}) {},
      );
      // No daemon running in test environment
      final connected = await client.connect('/tmp/nonexistent-project-dir');
      expect(connected, isFalse);
    });
  });
}
