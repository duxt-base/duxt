import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

/// Scaffolds a Tauri v2 project inside src-tauri/ of a Duxt project.
/// Used by both `duxt create --desktop` and `duxt build desktop`.
class TauriScaffold {
  /// Scaffold the src-tauri/ directory with Tauri v2 config.
  /// [projectDir] is the root of the Duxt project.
  /// [projectName] is the Dart package name from pubspec.yaml.
  static Future<void> scaffold(String projectDir, String projectName) async {
    final tauriDir = p.join(projectDir, 'src-tauri');
    final srcDir = p.join(tauriDir, 'src');
    final capsDir = p.join(tauriDir, 'capabilities');
    final iconsDir = p.join(tauriDir, 'icons');

    // Create directories
    await Directory(srcDir).create(recursive: true);
    await Directory(capsDir).create(recursive: true);
    await Directory(iconsDir).create(recursive: true);

    // Sanitize project name for Rust crate name (lowercase, underscores)
    final crateName = projectName.replaceAll('-', '_').toLowerCase();
    // Bundle identifier: only alphanumeric, hyphens, periods (no underscores)
    final bundleId = projectName.replaceAll('_', '-').toLowerCase();
    // Title case for display
    final displayName = projectName
        .split(RegExp(r'[-_]'))
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    // Cargo.toml
    await File(p.join(tauriDir, 'Cargo.toml')).writeAsString(cargoToml(crateName));
    print('  Created src-tauri/Cargo.toml');

    // tauri.conf.json
    await File(p.join(tauriDir, 'tauri.conf.json'))
        .writeAsString(tauriConf(displayName, bundleId));
    print('  Created src-tauri/tauri.conf.json');

    // src/lib.rs
    await File(p.join(srcDir, 'lib.rs')).writeAsString(libRs);
    print('  Created src-tauri/src/lib.rs');

    // src/main.rs
    await File(p.join(srcDir, 'main.rs')).writeAsString(mainRs);
    print('  Created src-tauri/src/main.rs');

    // build.rs
    await File(p.join(tauriDir, 'build.rs')).writeAsString(buildRs);
    print('  Created src-tauri/build.rs');

    // capabilities/default.json
    await File(p.join(capsDir, 'default.json')).writeAsString(defaultCapability);
    print('  Created src-tauri/capabilities/default.json');

    // Icons
    await _writeIcons(iconsDir, projectDir);
    print('  Created src-tauri/icons/');
  }

  // ---------------------------------------------------------------------------
  // Tauri templates
  // ---------------------------------------------------------------------------

  static String cargoToml(String crateName) => '''[package]
name = "$crateName-desktop"
version = "0.1.0"
edition = "2021"

[lib]
name = "app_lib"
crate-type = ["staticlib", "cdylib", "rlib"]

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
''';

  static String tauriConf(String displayName, String identifier) => jsonEncode({
        '\$schema':
            'https://raw.githubusercontent.com/tauri-apps/tauri/dev/crates/tauri-config-schema/schema.json',
        'productName': displayName,
        'version': '0.1.0',
        'identifier': 'dev.duxt.$identifier',
        'build': {
          'frontendDist': '../.output/public',
        },
        'app': {
          'windows': [
            {
              'title': displayName,
              'width': 1200,
              'height': 800,
              'resizable': true,
            }
          ],
          'security': {
            'csp': null,
          },
        },
        'bundle': {
          'active': true,
          'targets': 'all',
          'icon': [
            'icons/32x32.png',
            'icons/128x128.png',
            'icons/icon.icns',
            'icons/icon.ico',
          ],
        },
      });

  static const libRs = '''#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
''';

  static const mainRs =
      '''#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    app_lib::run();
}
''';

  static const buildRs = '''fn main() {
    tauri_build::build();
}
''';

  static const defaultCapability = '''{
  "\$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Default permissions",
  "windows": ["main"],
  "permissions": [
    "core:default"
  ]
}
''';

  /// Generate icons from bundled Duxt squircle icon asset.
  /// Uses `cargo tauri icon` if available, otherwise copies the source PNG.
  static Future<void> _writeIcons(String iconsDir, String projectDir) async {
    try {
      final assetUri = await Isolate.resolvePackageUri(
        Uri.parse('package:duxt/src/cli/assets/icon.png'),
      );
      if (assetUri != null) {
        final iconFile = File.fromUri(assetUri);
        if (await iconFile.exists()) {
          // Try cargo tauri icon to generate all sizes/formats
          final result = await Process.run(
            'cargo',
            ['tauri', 'icon', iconFile.path],
            workingDirectory: projectDir,
          );
          if (result.exitCode == 0) return;

          // Fallback: copy the source PNG for each expected icon slot
          final bytes = await iconFile.readAsBytes();
          await File(p.join(iconsDir, '32x32.png')).writeAsBytes(bytes);
          await File(p.join(iconsDir, '128x128.png')).writeAsBytes(bytes);
          await File(p.join(iconsDir, 'icon.icns')).writeAsBytes(bytes);
          await File(p.join(iconsDir, 'icon.ico')).writeAsBytes(bytes);
          return;
        }
      }
    } catch (_) {}

    // Last resort: generate a minimal cyan placeholder
    final png = _generateCyanPng(128, 128);
    await File(p.join(iconsDir, '32x32.png')).writeAsBytes(png);
    await File(p.join(iconsDir, '128x128.png')).writeAsBytes(png);
    await File(p.join(iconsDir, 'icon.icns')).writeAsBytes(png);
    await File(p.join(iconsDir, 'icon.ico')).writeAsBytes(png);
  }

  /// Generate a minimal valid RGBA PNG filled with Duxt cyan (#06b6d4)
  static Uint8List _generateCyanPng(int width, int height) {
    final out = BytesBuilder();
    out.add([137, 80, 78, 71, 13, 10, 26, 10]); // PNG signature

    final ihdr = BytesBuilder();
    ihdr.add(_uint32BE(width));
    ihdr.add(_uint32BE(height));
    ihdr.add([8, 6, 0, 0, 0]); // 8-bit RGBA
    out.add(_pngChunk('IHDR', ihdr.toBytes()));

    final raw = BytesBuilder();
    for (var y = 0; y < height; y++) {
      raw.addByte(0); // filter: none
      for (var x = 0; x < width; x++) {
        raw.add([0x06, 0xb6, 0xd4, 0xFF]); // RGBA cyan
      }
    }
    out.add(_pngChunk('IDAT', _zlibStore(raw.toBytes())));
    out.add(_pngChunk('IEND', Uint8List(0)));
    return out.toBytes();
  }

  static Uint8List _uint32BE(int v) =>
      Uint8List.fromList([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);

  static Uint8List _pngChunk(String type, Uint8List data) {
    final typeBytes = Uint8List.fromList(type.codeUnits);
    final crcInput = Uint8List.fromList([...typeBytes, ...data]);
    final crc = _crc32(crcInput);
    return Uint8List.fromList([
      ..._uint32BE(data.length),
      ...typeBytes,
      ...data,
      ..._uint32BE(crc),
    ]);
  }

  static Uint8List _zlibStore(Uint8List data) {
    final out = BytesBuilder();
    out.add([0x78, 0x01]);
    var offset = 0;
    while (offset < data.length) {
      final remaining = data.length - offset;
      final blockSize = remaining > 65535 ? 65535 : remaining;
      final isLast = (offset + blockSize) >= data.length;
      out.addByte(isLast ? 0x01 : 0x00);
      out.add([blockSize & 0xFF, (blockSize >> 8) & 0xFF]);
      out.add([~blockSize & 0xFF, (~blockSize >> 8) & 0xFF]);
      out.add(data.sublist(offset, offset + blockSize));
      offset += blockSize;
    }
    var a = 1, b = 0;
    for (final byte in data) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }
    out.add(_uint32BE((b << 16) | a));
    return out.toBytes();
  }

  static final _crc32Table = _buildCrc32Table();
  static List<int> _buildCrc32Table() {
    final table = List<int>.filled(256, 0);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
      }
      table[n] = c;
    }
    return table;
  }

  static int _crc32(Uint8List data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc = _crc32Table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }
}
