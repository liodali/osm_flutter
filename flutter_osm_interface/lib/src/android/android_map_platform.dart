import 'dart:async';

import 'package:flutter_osm_interface/src/android/android_map_event.dart';

/// Backend requested for an opt-in Android map session.
enum AndroidMapBackend {
  /// Try JNI during attach and fall back before any stateful command is sent.
  auto,

  /// Require the generated JNI transport.
  jni,

  /// Use the compatibility MethodChannel command transport.
  methodChannel,
}

/// Controller contract recognized by the Android platform-view widget.
///
/// This interface intentionally contains no JNI types so importing the normal
/// plugin and building iOS or Web does not initialize Android bindings.
abstract interface class AndroidMapPlatform {
  AndroidMapBackend get backend;

  AndroidMapBackend? get activeBackend;

  Future<void> get ready;

  Stream<AndroidMapEvent> get events;

  Future<void> attachAndroidMap(int viewId);
}
