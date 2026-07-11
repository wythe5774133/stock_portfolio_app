// integration_test 的 driver：把測試中的截圖存到 build/screenshots/。

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes,
        [Map<String, Object?>? args]) async {
      final File file = File('build/screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
