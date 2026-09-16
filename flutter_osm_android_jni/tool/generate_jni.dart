import 'dart:io';

import 'package:jnigen/jnigen.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');

  generateJniBindings(
    Config(
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          path: packageRoot.resolve('lib/src/android_jni/generated.dart'),
          structure: OutputStructure.singleFile,
        ),
      ),
      androidSdkConfig: AndroidSdkConfig(
        addGradleDeps: true,
        androidExample: packageRoot.resolve('../example/').toFilePath(),
      ),
      classes: const [
        'hamza.dali.flutter_osm_plugin.jni.OsmAndroidBridge',
      ],
    ),
  );
}
